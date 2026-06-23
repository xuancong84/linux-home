#!/opt/anaconda3/bin/python
"""scan.py

Recursively compare a local directory (folderA) with another directory which may be
- a local path, or
- an S3 bucket/path (e.g. ``s3://my-bucket/prefix``).

The script walks both sides side‑by‑side, reporting differences as they are
found.  By default only file size is compared to keep S3 API costs low; the
``--compare-content`` flag enables full MD5 checksum comparison.

Output format (printed on a single line while scanning)::

	scanned=<N> extra-A=<X> extra-B=<Y> diff=<Z>

When the scan finishes a final line with the same counters is printed.

The implementation follows the constraints from TASK.md:
- No ``os.walk`` – we manually recurse using ``os.scandir``.
- S3 listings use ``list_objects_v2`` pagination; no per‑object ``head_object``
calls.
- Progress is updated in‑place (carriage return) and nothing is printed if no
differences are found.
"""

import argparse, hashlib, os, shutil, sys, time, re
from collections import deque
from typing import Dict, List, Tuple, Union

try:
	import boto3
except ImportError:  # pragma: no cover – boto3 may not be installed in test env
	boto3 = None

# ---------------------------------------------------------------------------
# Helper utilities for local files
# ---------------------------------------------------------------------------

def list_local(dir_path: str) -> Tuple[Dict[str, int], List[str]]:
	"""Return a mapping of filename → size for files directly under ``dir_path``
	and a list of sub‑directory names (not full paths)."""
	files: Dict[str, int] = {}
	dirs: List[str] = []
	with os.scandir(dir_path) as it:
		for entry in it:
			if entry.is_file(follow_symlinks=False):
				files[entry.name] = entry.stat().st_size
			elif entry.is_dir(follow_symlinks=False):
				dirs.append(entry.name)
	return files, dirs


def file_md5(path: str) -> str:
	"""Calculate the MD5 checksum of a local file (read in chunks)."""
	hash_md5 = hashlib.md5()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(8192), b""):
			hash_md5.update(chunk)
	return hash_md5.hexdigest()

# ---------------------------------------------------------------------------
# Helper utilities for S3
# ---------------------------------------------------------------------------

def parse_s3_uri(uri: str) -> Tuple[str, str]:
	"""Split ``s3://bucket/prefix`` into bucket and prefix (no leading slash)."""
	assert uri.startswith("s3://")
	parts = uri[5:].split("/", 1)
	bucket = parts[0]
	prefix = ""
	if len(parts) == 2:
		prefix = parts[1].rstrip("/")
	return bucket, prefix


def list_s3(bucket: str, prefix: str) -> Tuple[Dict[str, int], List[str]]:
	"""List objects directly under ``prefix`` (non‑recursive) and "folders".

	Returns a ``files`` dict mapping key (basename) → size and a ``dirs`` list of
	common prefixes (relative to ``prefix``) without the trailing ``/``.
	"""
	if boto3 is None:
		raise RuntimeError("boto3 is required for S3 operations but is not installed")
	client = boto3.client("s3")
	paginator = client.get_paginator("list_objects_v2")
	files: Dict[str, int] = {}
	dirs_set = set()
	pagination_params = {"Bucket": bucket, "Prefix": prefix + "/" if prefix else "", "Delimiter": "/"}
	for page in paginator.paginate(**pagination_params):
		for obj in page.get("Contents", []):
			# Skip the folder placeholder object that S3 may emit when a "folder"
			# exists but has no file.
			key = obj["Key"]
			if key.endswith('/'):
				continue
			rel_key = key[len(prefix) + 1:] if prefix else key
			if "/" in rel_key:
				# Object is deeper than the current level – its top‑level folder is
				# captured in CommonPrefixes below.
				continue
			files[rel_key] = obj["Size"]
		for cp in page.get("CommonPrefixes", []):
			sub = cp["Prefix"]
			# Remove the current prefix and trailing slash
			rel = sub[len(prefix) + 1:] if prefix else sub
			rel = rel.rstrip('/')
			if rel:
				dirs_set.add(rel)
	return files, sorted(dirs_set)


def s3_object_md5(bucket: str, key: str) -> str:
	"""Fetch an object's ETag (MD5) – only used when ``--compare-content`` is set.
	``head_object`` is avoided for the full tree but acceptable for a single
	comparison because it is invoked lazily for mismatched sizes only.
	"""
	client = boto3.client("s3")
	resp = client.head_object(Bucket=bucket, Key=key)
	etag = resp.get("ETag", "").strip('"')
	return etag


def copy_file_local_to_local(src: str, dst: str) -> None:
    dst_dir = os.path.dirname(dst)
    if dst_dir and not os.path.isdir(dst_dir):
        os.makedirs(dst_dir, exist_ok=True)
    shutil.copy2(src, dst)


def copy_file_local_to_s3(local_path: str, bucket: str, key: str) -> None:
	while True:
		try:
			return boto3.client("s3").upload_file(local_path, bucket, key)
		except Exception as e:
			print(f"Error uploading {local_path} to {bucket}/{key}: {e}")
			time.sleep(2)

def copy_file_s3_to_local(bucket: str, key: str, local_path: str) -> None:
	local_dir = os.path.dirname(local_path)
	if local_dir and not os.path.isdir(local_dir):
		os.makedirs(local_dir, exist_ok=True)
	while True:
		try:
			return boto3.client("s3").download_file(bucket, key, local_path)
		except Exception as e:
			print(f"Error downloading {bucket}/{key} to {local_path}: {e}")
			time.sleep(2)

def should_ignore(path: str, ignore_regex: List[str]) -> bool:
	for regex in ignore_regex:
		if re.search(regex, path):
			return True
	return False


# ---------------------------------------------------------------------------
# Core comparison logic
# ---------------------------------------------------------------------------

def compare(
	path_a: str,
	path_b: Union[str, Tuple[str, str]],
	compare_content: bool,
	reconcile_mode: str = "",
	ignore_regex: List[str] = [],
) -> Tuple[int, int, int, int]:
	"""Recursively compare ``path_a`` (local) with ``path_b`` (local or S3).

	Returns a tuple ``(scanned, extra_a, extra_b, diff)`` where:
	- ``scanned``   – total number of items examined (files + dirs)
	- ``extra_a``   – items only present in A
	- ``extra_b``   – items only present in B
	- ``diff``      – files present in both sides but differing in size (or
	content when ``compare_content`` is True).
	"""
	# Counters
	scanned = ignored = extra_a = extra_b = diff = 0

	# Stack for depth‑first side‑by‑side traversal: (a_path, b_path, b_is_s3)
	stack = deque()
	stack.append((path_a, path_b, isinstance(path_b, tuple)))

	while stack:
		a_cur, b_cur, b_is_s3 = stack.pop()
		# Determine directory listings for the current level
		if b_is_s3:
			bucket, prefix = b_cur  # type: ignore
			# prefix already includes the relative path from root of bucket
			files_b, dirs_b = list_s3(bucket, prefix)
		else:
			files_b, dirs_b = list_local(b_cur)  # type: ignore
		files_a, dirs_a = list_local(a_cur)

		# Compare files at this level
		all_files = set(files_a) | set(files_b)
		for name in all_files:
			scanned += 1
			
			if should_ignore(os.path.join(a_cur, name), ignore_regex):
				ignored += 1
				continue
			
			size_a = files_a.get(name)
			size_b = files_b.get(name)
			if size_a is None:
				# B has extra file
				extra_b += 1
				b_path = os.path.join(b_cur, name) if not b_is_s3 else (f"s3://{bucket}/{prefix}/{name}" if prefix else f"s3://{bucket}/{name}")
				print(f"B has extra file {b_path} (size {size_b})")
				if "b2a" in reconcile_mode:
					if b_is_s3:
						copy_file_s3_to_local(bucket, os.path.join(prefix, name), os.path.join(a_cur, name))
					else:
						copy_file_local_to_local(os.path.join(b_cur, name), os.path.join(a_cur, name))
					print(f"Copied {b_path} to {os.path.join(a_cur, name)}")
				continue
			if size_b is None:
				# A has extra file
				extra_a += 1
				a_path = os.path.join(a_cur, name)
				print(f"A has extra file {a_path} (size {size_a})")
				if "a2b" in reconcile_mode:
					if b_is_s3:
						copy_file_local_to_s3(os.path.join(a_cur, name), bucket, os.path.join(prefix, name))
					else:
						copy_file_local_to_local(os.path.join(a_cur, name), os.path.join(b_cur, name))
					print(f"Copied {a_path} to {os.path.join(b_cur, name)}")
				continue
			# Both exist – compare size (and optionally content)
			if size_a != size_b:
				diff += 1
				a_path = os.path.join(a_cur, name)
				b_path = os.path.join(b_cur, name) if not b_is_s3 else (f"s3://{bucket}/{prefix}/{name}" if prefix else f"s3://{bucket}/{name}")
				print(f"Diff file {a_path} (size {size_a}) vs {b_path} (size {size_b})")
				continue
			if compare_content:
				# compute full checksum for local file
				local_md5 = file_md5(os.path.join(a_cur, name))
				if b_is_s3:
					bucket, prefix = b_cur  # type: ignore
					key = f"{prefix}/{name}" if prefix else name
					s3_md5 = s3_object_md5(bucket, key)
				else:
					s3_md5 = file_md5(os.path.join(b_cur, name))  # type: ignore
				if local_md5 != s3_md5:
					diff += 1
					a_path = os.path.join(a_cur, name)
					b_path = os.path.join(b_cur, name) if not b_is_s3 else (f"s3://{bucket}/{prefix}/{name}" if prefix else f"s3://{bucket}/{name}")
					print(f"Diff file {a_path} (size {size_a}, md5 {local_md5}) vs {b_path} (size {size_b}, md5 {s3_md5})")
		# Queue sub‑directories for side‑by‑side walk
		all_dirs = set(dirs_a) | set(dirs_b)
		for d in all_dirs:
			a_sub = os.path.join(a_cur, d)
			if should_ignore(a_sub, ignore_regex):
				continue
			if b_is_s3:
				bucket, prefix = b_cur  # type: ignore
				b_sub = (bucket, f"{prefix}/{d}" if prefix else d)
				b_is_sub_s3 = True
			else:
				b_sub = os.path.join(b_cur, d)  # type: ignore
				b_is_sub_s3 = False
			# If a side is missing, count the whole subtree as extra items.
			# For simplicity we count only the top‑level folder as an extra.
			if d not in dirs_a:
				extra_b += 1
				continue
			if d not in dirs_b:
				extra_a += 1
				continue
			# Both have the directory – descend.
			stack.append((a_sub, b_sub, b_is_sub_s3))
		# Update progress line
		print(f"scanned={scanned} extra-A={extra_a} extra-B={extra_b} diff={diff}", end='\r', file=sys.stderr, flush=True)
	# Ensure final newline
	print(file=sys.stderr, flush=True)
	return scanned, extra_a, extra_b, diff

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
	parser = argparse.ArgumentParser(description="Side‑by‑side recursive diff between a local folder and another folder (local or S3).")
	parser.add_argument("folderA", help="Path to the local directory.")
	parser.add_argument("folderB", help="Path to the other directory – can be a local path or an S3 URI (s3://bucket/prefix).")
	parser.add_argument(
		"--compare-content",
		action="store_true",
		help="When set, compare full file content (MD5) after a size match.",
	)
	parser.add_argument(
		"--reconcile",
		default="",
		help="Reconcile differences by copying extra items: "
			"a2b = copy missing items from A to B, "
			"b2a = copy from B to A, "
			"a2b:b2a = copy each side's extras to the other.",
	)
	parser.add_argument(
		"--ignore-regex",
		default=[],
		help="Regex to ignore files and directories.",
		nargs="+",
	)
	args = parser.parse_args()

	if not os.path.isdir(args.folderA):
		sys.exit(f"Error: folderA '{args.folderA}' does not exist or is not a directory.")

	# Determine whether folderB is S3 or local
	if args.folderB.startswith("s3://"):
		if boto3 is None:
			sys.exit("Error: boto3 is required for S3 support but is not installed.")
		bucket, prefix = parse_s3_uri(args.folderB)
		path_b: Union[str, Tuple[str, str]] = (bucket, prefix)
	else:
		if not os.path.isdir(args.folderB):
			sys.exit(f"Error: folderB '{args.folderB}' does not exist or is not a directory.")
		path_b = args.folderB

	scanned, extra_a, extra_b, diff = compare(args.folderA, path_b, args.compare_content, args.reconcile, args.ignore_regex)
	# Final summary (already printed by compare, but repeat for clarity)
	print(f"Total scanned: {scanned}, extra in A: {extra_a}, extra in B: {extra_b}, differing files: {diff}")

if __name__ == "__main__":
	main()

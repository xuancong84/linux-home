#!/usr/bin/env python3
import argparse
import datetime as dt
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional

DATE_RE = re.compile(
	r'(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+'
	r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+'
	r'(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})'
)

# Accounts shown by `last` that are not real user logins
PSEUDO_USERS = {"reboot", "shutdown", "runlevel", "wtmp", "btmp"}

# Shells that indicate the account is intentionally non-login
NOLOGIN_SHELLS = {
	"/nologin", "/false"
}

def parse_args():
	p = argparse.ArgumentParser(
		usage='$0 [options] wtmp passwd shadow 1>new_shadow 2>summary',
		description="Print out new shadow file if inactive (no login for 90 days) user list has changed.",
		formatter_class=argparse.ArgumentDefaultsHelpFormatter
	)
	p.add_argument("--pam-unlock-log", "-pu", help="Path to the pam-unlock log file")
	p.add_argument("wtmp_path", help="Path to wtmp file (e.g., /var/log/wtmp)")
	p.add_argument("passwd_path", help="Path to passwd file (e.g., /etc/passwd)")
	p.add_argument("shadow_path", help="Path to shadow file (e.g., /etc/shadow)")
	return p.parse_args()

def run_last(wtmp_path: str) -> str:
	# Force C locale to get English month/day names so parsing works reliably.
	env = os.environ.copy()
	env["LC_ALL"] = "C"
	try:
		cp = subprocess.run(
			["last", "-F", "-w", "-f", wtmp_path],
			env=env,
			check=True,
			capture_output=True,
			text=True,
		)
	except FileNotFoundError:
		sys.exit("ERROR: `last` command not found on this system.")
	except subprocess.CalledProcessError as e:
		sys.exit(f"ERROR running last: {e.stderr.strip() or e.stdout.strip()}")
	return cp.stdout

def parse_last_output(output: str) -> Dict[str, dt.datetime]:
	"""
	Return a mapping: username -> most recent login datetime (local time, naive).
	"""
	user_last: Dict[str, dt.datetime] = {}
	for raw in output.splitlines():
		line = raw.rstrip()
		if not line or line.endswith("wtmp begins") or line.endswith("btmp begins"):
			continue
		first_tok = line.split(None, 1)[0] if line.strip() else ""
		if not first_tok or first_tok in PSEUDO_USERS:
			continue

		# Find the first full timestamp; with -F there should be one
		m = DATE_RE.search(line)
		if not m:
			continue  # skip unparseable lines

		dow, mon, day, hh, mm, ss, year = m.groups()
		date_str = f"{dow} {mon} {int(day):02d} {hh}:{mm}:{ss} {year}"
		try:
			ts = dt.datetime.strptime(date_str, "%a %b %d %H:%M:%S %Y")
		except ValueError:
			continue

		# Keep the most recent timestamp per user
		u = first_tok
		if (u not in user_last) or (ts > user_last[u]):
			user_last[u] = ts
	return user_last

def parse_pam_unlock_log(path: str) -> Dict[str, dt.datetime]:
	"""
	Parse pam-unlock log lines of the form:
	2025-09-26 09:59:42+08:00 PAM_TTY=:0 PAM_USER=xuancong PAM_TYPE=auth

	Returns mapping: username -> most recent login datetime (local time, naive).
	Only counts entries where PAM_TYPE=auth.
	"""
	user_last: Dict[str, dt.datetime] = {}

	if not path:
		return user_last
	try:
		with open(path, "r", encoding="utf-8", errors="ignore") as f:
			for raw in f:
				line = raw.strip()
				if not line:
					continue

				# Expect first two tokens to be date and time+offset
				# Example: "2025-09-26 09:59:42+08:00 ..."
				parts = line.split()
				if len(parts) < 3:
					continue

				# Extract key=value tokens
				# We only care about PAM_USER and PAM_TYPE
				pam_type: Optional[str] = None
				pam_user: Optional[str] = None
				for tok in parts[2:]:
					if tok.startswith("PAM_TYPE="):
						pam_type = tok.split("=", 1)[1]
					elif tok.startswith("PAM_USER="):
						pam_user = tok.split("=", 1)[1]

				if pam_type != "auth" or not pam_user:
					continue

				# Parse timestamp with timezone offset, then convert to local naive
				ts_str = parts[0] + " " + parts[1]
				try:
					ts_aware = dt.datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S%z")
				except ValueError:
					# Be lenient if there is a 'T' between date and time
					try:
						ts_aware = dt.datetime.strptime(parts[0] + "T" + parts[1], "%Y-%m-%dT%H:%M:%S%z")
					except ValueError:
						continue
				# Convert to local time and drop tzinfo to match `last` parsing
				ts_local = ts_aware.astimezone().replace(tzinfo=None)

				if (pam_user not in user_last) or (ts_local > user_last[pam_user]):
					user_last[pam_user] = ts_local
	except FileNotFoundError:
		# If the file isn't there, just ignore it (treat as no extra activity)
		pass
	return user_last

def read_passwd(passwd_path: str) -> Dict[str, Tuple[int, str]]:
	"""
	Return mapping: username -> (uid, shell)
	"""
	users: Dict[str, Tuple[int, str]] = {}
	with open(passwd_path, "r", encoding="utf-8", errors="ignore") as f:
		for line in f:
			line = line.rstrip("\n")
			if not line or line.startswith("#"):
				continue
			parts = line.split(":")
			if len(parts) < 7:
				continue
			name, _, uid_s, _gid, _gecos, _home, shell = parts[:7]
			try:
				uid = int(uid_s)
			except ValueError:
				continue
			users[name] = (uid, shell)
	return users

def read_shadow(shadow_path: str) -> Dict[str, List[str]]:
	"""
	Return mapping: username -> list of 9 shadow fields (mutable).
	Also returns full order in a separate list if needed.
	"""
	entries: Dict[str, List[str]] = {}
	with open(shadow_path, "r", encoding="utf-8", errors="ignore") as f:
		for line in f:
			line = line.rstrip("\n")
			if not line:
				continue
			parts = line.split(":")
			# pad to 9 fields if fewer present
			while len(parts) < 9:
				parts.append("")
			entries[parts[0]] = parts
	return entries

def write_shadow(fp, entries: Dict[str, List[str]]) -> None:
	for user,items in entries.items():
		fp.write(":".join(items) + "\n")

def main():
	args = parse_args()
	cutoff = dt.datetime.now() - dt.timedelta(days=90)

	# Collect last login times from wtmp via `last`
	last_out = run_last(args.wtmp_path)
	last_login = parse_last_output(last_out)

	# Optionally merge in pam-unlock log activity
	if args.pam_unlock_log:
		pam_last = parse_pam_unlock_log(args.pam_unlock_log)
		for user, ts in pam_last.items():
			prev = last_login.get(user)
			if (prev is None) or (ts > prev):
				last_login[user] = ts

	passwd = read_passwd(args.passwd_path)
	shadow = read_shadow(args.shadow_path)

	# Candidate users: those present in both passwd and shadow,
	# ignore root (uid 0), ignore typical system users (uid < 1000),
	# and ignore non-login shells.
	candidates: Set[str] = set()
	for user, (uid, shell) in passwd.items():
		if user not in shadow:
			continue
		if uid == 0:
			continue
		if uid < 1000:
			continue
		if [1 for sf in NOLOGIN_SHELLS if shell.endswith(sf)]:
			continue
		candidates.add(user)

	# Determine who is inactive: no login ever recorded, or last login < cutoff.
	inactive: Set[str] = set()
	for user in candidates:
		ts = last_login.get(user)
		if ts is None or ts < cutoff:
			inactive.add(user)

	# Lock newly inactive users that are not already locked.
	changed_users: List[str] = []
	for user in sorted(inactive):
		fields = shadow.get(user)
		if not fields:
			continue
		pwd = fields[1]
		if not pwd:
			# Empty password -> lock by setting to "!"
			fields[1] = "!"
			changed_users.append(user)
		elif not pwd.startswith("!"):
			# Prepend '!' to lock
			fields[1] = "!" + pwd
			changed_users.append(user)
		# else already locked; no change

	# Write file only if something changed
	if changed_users:
		write_shadow(sys.stdout, shadow)

	# Optional summary to stderr (keeps stdout as pure shadow content)
	sys.stderr.write("\nSummary:\n")
	if changed_users:
		sys.stderr.write("Locked (inactive >= 90 days): " + ", ".join(changed_users) + "\n")
	else:
		sys.stderr.write("No changes (no newly inactive users to lock).\n")

if __name__ == "__main__":
	# Require root when operating on real /etc/shadow, but don't hard-enforce here.
	main()

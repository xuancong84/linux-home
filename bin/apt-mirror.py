#!/usr/bin/env python3
# coding=utf-8

import os, sys, argparse, re, gzip, hashlib, requests, fnmatch, signal, lzma, io
import time
from glob import glob
from collections import *

isExiting = False
old_sig = signal.getsignal(signal.SIGINT)
def signal_handler(sig, frame):
	global isExiting, old_sig
	isExiting = True
	print('\nCtrl+C pressed, please wait while finish downloading the current file!')
	print('\nWarning: pressing Ctrl+C again will terminate the download, giving rise to the incomplete file', flush=True)
	signal.signal(signal.SIGINT, old_sig)

def Open(fn, mode = 'rt', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	elif fn.lower().endswith('.gz'):
		return gzip.open(fn, mode, **kwargs)
	elif fn.lower().endswith('.xz'):
		return lzma.open(fn, mode, **kwargs)
	return open(fn, mode, **kwargs)

def OpenPrefix(fn, mode = 'rt', **kwargs):
	flist = [afn for afn in [fn, fn+'.gz', fn+'.xz'] if os.path.isfile(afn)]
	if not flist:
		print('Skip: none of these files exists '+str([fn, fn+'.gz', fn+'.xz']), flush = True)
		return io.StringIO()
	return Open(flist[0], mode, **kwargs)

def delete_file(full_name):
	try: os.remove(full_name)
	except: pass

def makedirs(path):
	if os.path.isfile(path):
		delete_file(path)
	return os.makedirs(path, exist_ok = True)

strip_http = lambda s: re.sub('^https*://', '', s)
make_path = lambda its: re.sub(r'/+', '/', '/'.join([strip_http(s) for s in its])).rstrip('/')

def wget_recurse_all(outdir, param):
	return os.system("wget -N -r -np -l 9999 -P %s --reject-regex '.*\?.*' %s" % (outdir, param.rstrip('/')+'/'))

def wget_current_dir(outdir, param):
	return os.system("wget -N -r -np -l 1    -P %s --reject-regex '(.*\?.*)|($1/.*/.*)' %s" % (outdir, param.rstrip('/')+'/'))

def wget_file(outdir, file_url):
	out_fullpath = make_path([outdir, file_url])
	makedirs(os.path.dirname(out_fullpath))
	return os.system("wget -O %s %s" % (out_fullpath, file_url))

# parse the Release file
def parse_Release(fn):
	Ls = Open(fn).read().splitlines()
	if 'MD5Sum:' in Ls:
		n_start = Ls.index('MD5Sum:')+1
	elif 'SHA1:' in Ls:
		n_start = Ls.index('SHA1:')+1
	elif 'SHA256:' in Ls:
		n_start = Ls.index('SHA256:') + 1
	else:
		sys.exit('Fatal: No hash checksum found in '+fn)
	ret = []
	for L in Ls[n_start:]:
		its = L.split()
		if len(its) != 3: break
		ret += [its]
	return ret

# parse the Package file
def parse_Packages(fn):
	ret, d = [], {}
	for L in OpenPrefix(fn).readlines():
		if not L.strip():
			keys = [k for k in ['md5sum', 'sha1', 'sha256'] if k in d]
			if not keys:
				sys.exit('Fatal: No hash checksum found in '+fn)
			ret += [[d[keys[0]], d['size'], d['filename']]]
			continue
		its = L.split(':')
		if len(its)==2:
			d[its[0].strip().lower()] = its[1].strip()
	return ret

def verify_checksum(fullpath, cksum):
	fdata = open(fullpath, 'rb').read()
	if len(cksum)==32:
		return cksum == hashlib.md5(fdata).hexdigest()
	elif len(cksum)==40:
		return cksum == hashlib.sha1(fdata).hexdigest()
	elif len(cksum)==64:
		return cksum == hashlib.sha256(fdata).hexdigest()
	sys.exit('Unknown checksum for file ' + fullpath)

def unchecked_download(input_url, output_path, filesize=None, chksum=None):
	# output_path: if ends with /, it is treated as the default output root directory
	#               otherwise, it is treated as the full file path
	output_fullpath = make_path([output_path, input_url]) if output_path.endswith('/') else output_path
	i = 0
	for fail in range(3):
		try:
			with requests.get(input_url, stream = True, timeout = timeout) as r:
				r.raise_for_status()
				makedirs(os.path.dirname(output_fullpath))
				with open(output_fullpath, 'wb') as f:
					for chunk in r.iter_content(chunk_size = 65536 if fail else 1048576):
						f.write(chunk)
						i += 1
						print(_progress_spin[i % len(_progress_spin)], end = '\b', flush = True)
				if filesize is not None and os.path.getsize(output_fullpath) != int(filesize):
					print(f'Downloaded file {output_fullpath} has incorrect size, tried {fail+1} times ...')
					delete_file(output_fullpath)
					continue
				if chksum is not None and not verify_checksum(output_fullpath, chksum):
					print(f'Downloaded file {output_fullpath} has incorrect checksum, tried {fail+1} times ...')
					delete_file(output_fullpath)
					continue
				return True
		except Exception as e:
			if not isinstance(e, requests.exceptions.ConnectionError):
				delete_file(output_fullpath)
			if hasattr(e, 'response') and hasattr(e.response, 'status_code') and e.response.status_code == 404:
				break
			print('\nError downloading', output_fullpath, '; tried %d times' % (fail + 1))
			time.sleep(1)
	return False

# check filesize and md5, and download it if mismatch
_progress_spin = '-\\|/'
def checked_download(url_prefix, md5_sz_fn_list, output_dir= '', checksum='both'):
	global isExiting, old_sig, timeout

	url_prefix = url_prefix.rstrip('/')+'/'
	rel_path = make_path([output_dir, url_prefix])
	N, n = len(md5_sz_fn_list), 0
	for md5, sz, fn in md5_sz_fn_list:
		# Set Ctrl+C handler
		signal.signal(signal.SIGINT, signal_handler)

		if isExiting:
			print('\nCtrl+C pressed, exiting!', flush = True)
			sys.exit(0)

		if n%5 == 0:
			print('\r%d / %d *' % (n, N), end = '\b', flush = True)

		# Skip download if file size and checksum matches
		fullpath = make_path([rel_path, fn])
		if os.path.isfile(fullpath) and os.path.getsize(fullpath) == int(sz) and \
				(verify_checksum(fullpath, md5) if checksum in ['old', 'both'] else True):
			n += 1
			continue

		# If file size is 0, delete the file if it already exists
		if sz==0 and os.path.isfile(fullpath):
			delete_file(fullpath)
			n += 1
			continue

		print('\r%d / %d %s' % (n, N, _progress_spin[0]), end = '\b', flush = True)
		unchecked_download(url_prefix+fn, fullpath, filesize = int(sz), chksum = (md5 if checksum in ['new', 'both'] else None) )
		n += 1

	# Restore Ctrl+C handler
	signal.signal(signal.SIGINT, old_sig)
	print('\r%d / %d'%(n, N), flush = True)


if __name__ == '__main__':
	parser = argparse.ArgumentParser(usage = '$0 output_directory [options] 1>output 2>progress', description = 'Python3-version apt-mirror',
	                                 formatter_class = argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('output_dir', help = 'output directory')
	parser.add_argument('--inputs', '-i', help = 'input sources.list (by default, it uses your system settings in /etc/apt/*)', nargs = '+',
	                    default = ['/etc/apt/sources.list', '/etc/apt/sources.list.d/*.list'])
	parser.add_argument('--checksum', help = 'verify checksum for existing files (old), downloaded files (new), or both (by default);'
						'even though checksum verification can be disabled, file size verification will always be enabled',
	                    default = 'new', choices = ['none', 'old', 'new', 'both'])
	parser.add_argument('--index-checksum', help = 'verify checksum for existing index files (old), downloaded index files (new), or both (by default);'
                        'even though checksum verification can be disabled, file size verification will always be enabled',
	                    default = 'both', choices = ['none', 'old', 'new', 'both'])
	parser.add_argument('--timeout', '-t', help = 'connection timeout (in seconds)', default = 10, type = int)
	parser.add_argument('--delete-old', '-D', help = 'delete old files in pool that are not in Level 2 index', action = 'store_true')
	# nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt = parser.parse_args()
	globals().update(vars(opt))

	output_dir = os.path.expanduser(output_dir)
	inputs = [os.path.expanduser(i) for i in inputs]

	# 1. gather all deb lines from all *.list
	deb_lines = [L.strip() for patn in inputs for f in glob(patn) for L in Open(f).readlines() if L.strip().startswith('deb')]

	# 2. organize data structures
	repos = defaultdict(lambda: defaultdict(lambda : set()))
	for L in deb_lines:
		# parse, extract, and remove options from L
		try:
			L1, opt = L, {}
			for options in re.findall(r'\[[^]]*\]', L):
				for option in options[1:-1].split():
					k, v = option.split('=')
					if k=='arch' or k=='arch+':
						opt[k] = v.split(',')
					elif k=='arch-':
						opt[k] = ['!'+i for i in v.split(',')]
				L1 = L1.replace(options, '')

			its = L1.split()
			opt['source'] = its[0].endswith('-src')
			for pool in its[3:]:
				repos[its[1]][its[2]].add(pool+' '+str(opt))
		except:
			print('Malformed line:', L)

	# 3. clone every repo
	contain_arch = lambda fn, arch: re.search(r'-%s[./-]' % arch, fn) or fn.endswith('-' + arch)
	for url, dist_pool_options in repos.items():

		# if 'gooasdfgle' not in url: continue    # DEBUG

		url_filelist = []
		for dist, pool_options in dist_pool_options.items():
			url = url.rstrip('/')
			url_nohttp = re.sub(r'^https*://', '', url)

			# Firstly, download the distrib root index with timestamp awareness
			wget_current_dir(output_dir, '%s/dists/%s/'%(url, dist))
			if not os.path.isfile('%s/%s/dists/%s/Release'%(output_dir, url_nohttp, dist)):
				unchecked_download('%s/dists/%s/Release'%(url, dist), output_dir+'/')

			if not os.path.isfile('%s/%s/dists/%s/Release' % (output_dir, url_nohttp, dist)):
				print('SKIP: unable to download', '%s/dists/%s/Release'%(url, dist), flush = True)
				continue

			# Parse the Release file
			level1 = parse_Release('%s/%s/dists/%s/Release'%(output_dir, url_nohttp, dist))

			for pool_option in pool_options:
				pool, option = pool_option.split(' ', 1)
				option = eval(option)

				# For deb-src, only download the entire <dist>/<pool>/source/ folder and all -source
				if option.get('source', False):
					wget_recurse_all(output_dir, '%s/dists/%s/%s/source/' % (url, dist, pool))
					flist = [(md5, file_size, file_name) for md5, file_size, file_name in level1 if file_name.startswith(pool+'/') and '-source' in file_name]
					checked_download('%s/dists/%s/' % (url, dist), flist, output_dir, checksum = checksum)
					continue

				# If arch is specified, build exclusion patterns
				exclude_patns = []
				for patn in option.get('arch', []):
					for md5, file_size, file_name in level1:
						if contain_arch(file_name, patn):
							exclude_patns += [file_name.replace(patn, '%s')]
					break

				# Fetch level2 indices
				flist = []
				for md5, file_size, file_name in level1:
					if not file_name.startswith(pool+'/'): continue
					if '/source/' in file_name: continue
					if set([(1 if file_name in [patn%arch for arch in option['arch']] else 0) for patn in exclude_patns if fnmatch.fnmatch(file_name, patn%'*')])==set([0]):
						continue
					flist += [[md5, file_size, file_name]]
				print('Fetching Level 2 indices for', url, dist, pool, '...', flush = True)
				checked_download('%s/dists/%s/' % (url, dist), flist, output_dir, checksum = index_checksum)


				# Secondly, download the distrib's pool index with timestamp awareness
				for _, _, fn in flist:
					if not fn.endswith('/Packages'): continue
					pkg_filename = make_path([output_dir, url, 'dists', dist, fn])
					md5_sz_fn_list = parse_Packages(pkg_filename)
					if md5_sz_fn_list:
						print('Downloading packages in', pkg_filename, '...', flush = True)
						checked_download(url, md5_sz_fn_list, output_dir, checksum = checksum)
						url_filelist += [make_path([output_dir, url, c]) for a, b, c in md5_sz_fn_list]
					else:
						print('There are 0 packages in', pkg_filename, '=> Skip', flush = True)
					print(flush = True)

		if delete_old:
			url_fileset = set(url_filelist)
			path_prefix = make_path([output_dir, url, 'pool'])
			print('Deleting old files from', path_prefix, flush = True)
			N_total = N_deleted = 0
			for path, dir_list, file_list in os.walk(path_prefix, followlinks = True):
				for filename in file_list:
					N_total += 1
					fullname = path+'/'+filename
					if fullname not in url_fileset:
						N_deleted += 1
						delete_file(fullname)
				print('%d / %d deleted  '%(N_deleted, N_total), end = '\r', flush = True)
			print('%d / %d deleted ... Done'%(N_deleted, N_total), flush = True)

	with open(output_dir+'/sources.list', 'wt') as fp:
		for url, dist_pool_options in repos.items():
			for dist, pool_options in dist_pool_options.items():
				print('deb [trusted=yes] file://%s %s %s'%(make_path([output_dir, url]), dist, ' '.join([i.split()[0] for i in pool_options])), file = fp)
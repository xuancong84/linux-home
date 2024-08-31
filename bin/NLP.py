#!/usr/bin/env python3
import os, sys, gzip

def Try(*args):
	exc = ''
	for arg in args:
		try:
			return arg() if callable(arg) else arg
		except Exception as e:
			exc = e
	return str(exc)

expand_path = lambda t: os.path.expandvars(os.path.expanduser(t))

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = expand_path(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)


def load_linegroups(obj):
	if type(obj)==str:
		if os.path.isfile(obj):
			obj = Open(obj).read()
		return [lg.split('\n') for lg in obj.split('\n\n')]
	elif hasattr(obj, 'read'):
		return [lg.split('\n') for lg in obj.read().split('\n\n')]

def save_linegroups(fnfp, obj):
	fp = Open(fnfp,'wt') if type(fnfp)==str else fnfp
	fp.write('\n'.join(['\n'.join(lg) for lg in obj]))
	fp.close()


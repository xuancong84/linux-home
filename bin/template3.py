#!/usr/bin/env python3
# coding=utf-8

import os,sys,argparse,re


def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 arg1 1>output 2>progress', description='what this program does',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('positional', help='positional argument')
	parser.add_argument('-optional', help='optional argument')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	while True:
		try:
			L=input()
		except:
			break
		print(L, 'ok', flush=True)

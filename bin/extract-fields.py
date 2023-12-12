#!/usr/bin/env python3

import os, sys, argparse, gzip, math

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

def format(f, fmt):
	try:
		v=float(f)
		return str(int(v)) if v.is_integer() else fmt%float(f)
	except:
		return f

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 fields <input >output-line', description='extract relevant fields to produce a line',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('fields', help='a list of field specifiers, each one is row:col, 0-based', nargs='+')
	parser.add_argument('--delimiter', '-d', default='\t', help='output delimiter')
	parser.add_argument('--fmt', '-f', default='%.3g', help='output numeric format specifier')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	specs = [[int(i) for i in f.split(':')] for f in fields]
	INPUT = [L.split() for L in sys.stdin.readlines()]

	print(delimiter.join([format(INPUT[s[0]][s[1]], fmt) for s in specs]))

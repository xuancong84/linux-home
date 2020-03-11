#!/usr/bin/env python3
# coding=utf-8

import os, sys, argparse, re, gzip
import pandas as pd

def Open(fn, mode='r'):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	return gzip.open(fn, mode) if fn.lower().endswith('.gz') else open(fn, mode)

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [input-files ...] 1>output 2>progress',
									 description='concatenate CSV files; if filenames is empty, it will take every line as an input-filenames')
	parser.add_argument('filenames', help='list of input csv filenames', nargs='*')
	parser.add_argument('--error-bad-lines', '-e', help='how to handle bad lines', action='store_true')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if not filenames:
		df = pd.DataFrame()
		while True:
			try:
				df.append(pd.read_csv(Open(input()), error_bad_lines=error_bad_lines))
			except:
				break
		print(df.to_csv(index=False))
	else:
		df = pd.concat([pd.read_csv(Open(fn), error_bad_lines=error_bad_lines) for fn in filenames])
		print(df.to_csv(index=False))

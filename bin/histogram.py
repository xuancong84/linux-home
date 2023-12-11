#!/usr/bin/env python3

import os, sys, argparse, gzip, math
from numpy import *
import pandas as pd
import matplotlib.pyplot as plt

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 arg1 1>output 2>progress', description='what this program does',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('files', help='input filenames, if empty, take input from STDIN', nargs='*')
	parser.add_argument('-b', '--bins', default='10', help='histogram bins')
	parser.add_argument('-s', '--skip-header', help='skip CSV header (by default, it will use it as column name)', action='store_true')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if files:
		INPUT = [L for f in files for L in Open(f).read().splitlines()[(1 if skip_header else 0):]]
	else:
		INPUT = sys.stdin

	arr=[]
	name=None
	for L in INPUT:
		for w in L.split():
			try:
				arr+=[float(w)]
			except:
				name=w if name==None else name

	df = pd.DataFrame(arr, columns=[name.decode() if type(name)==bytes else name])
	df.hist(bins=eval(bins))
	plt.show()
	input()

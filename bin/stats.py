#!/usr/bin/env python3

import os, sys, argparse, gzip, math
from numpy import *
from collections import Counter

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

def entropy(c: Counter):
	N=sum(list(c.values()))
	return sum([-(v/N)*math.log(v/N) for k,v in c.items()])

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [options] [files ...]', description='compute statistics on input data',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('files', help='input filenames, if empty, take input from STDIN', nargs='*')
	parser.add_argument('-s', '--skip-header', help='skip CSV header (the 1st line)', action='store_true')
	parser.add_argument('-n', '--n-most-common', default=5, type=int, help='N most common')
	parser.add_argument('-nc', '--no-counts', help='no counts in n-most-common', action='store_true')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if files:
		INPUT = [L for f in files for L in Open(f).read().splitlines()[(1 if skip_header else 0):]]
	else:
		INPUT = sys.stdin

	name=None
	arr=[]
	for L in INPUT:
		for w in L.split():
			try:
				arr+=[float(w)]
			except:
				name=w if name==None else name

	cnter = Counter(arr)

	if name!=None:
		print('name=', name)
	print('max=', max(arr))
	print('min=', min(arr))
	print('mean=', mean(arr))
	print('median=', median(arr))
	print('std=', std(arr))
	if n_most_common:
		print(f'top_{n_most_common}=', [i for i,j in cnter.most_common(n_most_common)] if no_counts else cnter.most_common(n_most_common))
	print('entropy=', entropy(cnter))
	print('n_diff=', len(cnter))
	print('n_total=', len(arr))


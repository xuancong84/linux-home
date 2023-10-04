#!/usr/bin/env python3
# coding=utf-8

import os,sys,argparse,re,math
from collections import *

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 <input >output', description='Counter().most_common()',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('-e', '--entropy', help='compute entropy', action='store_true')
	parser.add_argument('-c', '--counts', help='count # of different values', action='store_true')
	parser.add_argument('-n', '--normalized', help='normalized counts', action='store_true')
	parser.add_argument('-tr', '--table-row', help='output table row of [name,#-diff-values,entropy,top4-names]', action='store_true')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	data = sys.stdin.read().splitlines()
	cnter1 = Counter(data)
	cnter = cnter1.most_common()

	if table_row:
		key=[k for k in cnter1 if k.isalpha()][0]
		cnter1.pop(key)
		cnter2 = cnter1.most_common()
		E=0
		N=sum(cnter1.values())
		for k,v in cnter2:
			p=v/N
			E-=p*math.log(p)
		print(f'{key}\t{len(cnter2)}\t%.3f\t{[k[0] for k in cnter2[0:4]]}'%E)
		sys.exit(0)

	print(cnter)

	if normalized:
		N=sum(cnter1.values())
		print([(i,'%.3f'%(j/N)) for i,j in cnter])

	if counts:
		print(f'Counts={len(cnter)}')

	if entropy:
		E=0
		N=len(data)
		for k,v in cnter:
			p=v/N
			E-=p*math.log(p)
		print(f'Entropy={E}')



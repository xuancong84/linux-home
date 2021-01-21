#!/usr/bin/env python3

import os,sys,argparse,numpy
from numpy import *

lmap = lambda func, *iterable: list(map(func, *iterable))

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [axis] 1>output 2>progress', description='It computes the average of STDIN')
	parser.add_argument('-axis', help='the axis along which the sum is computed, 0 is the outer (column), 1 is the inner (row)', default=None, type=int)
	parser.add_argument('-delimiter', help='entry delimiter, default="\\t"', default="\t", type=str)
	parser.add_argument('-func', help='the reduction function, default=<filename>', default=None, type=str)
	parser.add_argument('-fmt', help='output floating format', default='%.6f', type=str)
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if not func:
		func=os.path.basename(sys.argv[0]).rsplit('.',1)[0]
	F = eval('numpy.'+func)
	delimiter=delimiter.encode('utf8').decode('unicode_escape')

	if axis==0:
		arr=[]
		for L in sys.stdin:
			arr+=[lmap(float,L.split())]
		S = F(array(arr), axis).tolist()
		print(delimiter.join([fmt%v for v in S]))
	elif axis==1:
		while True:
			L = sys.stdin.readline()
			if L=='':
				break
			print(fmt%F(lmap(float,L.split())), flush=True)
	else:
		arr=[]
		for L in sys.stdin:
			arr+=L.split()
		print(fmt%F(lmap(float,arr)))


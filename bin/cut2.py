#!/usr/bin/env python2

import sys,os

if len(sys.argv)==1:
	print >>sys.stderr, 'Usage: $0 columns <input >output'
	print >>sys.stderr, 'example columns (1-based): 1-3 3--1 -2'
	sys.exit(1)

posis=[]
for arg in sys.argv[1:]:
	posis.extend(arg.strip().split(','))

n=0
for line in sys.stdin:
	n+=1
	line=line.strip()
	token_list=line.split()
	for arg in posis:
		i=arg.find('-')
		if i==(len(arg)-1):
			start_pos=int(arg[:i])-1
			for j in range(start_pos, len(token_list)):
				print token_list[j],
		elif i==0:
			pos=int(arg)
			if token_list!=[]:
				print token_list[pos],
		elif i!=-1:
			start_pos=int(arg[:i])-1
			to=int(arg[i+1:])
			if to>=0:
				end_pos=to-1
			else:
				end_pos=len(token_list)+to-1
			for j in range(start_pos, end_pos+1):
				if j >= len(token_list):
					break
				print token_list[j],
		else:
			pos=int(arg)-1
			if pos<len(token_list):
				print token_list[pos],
	print ''

print >>sys.stderr, n

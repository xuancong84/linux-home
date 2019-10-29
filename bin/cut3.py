#!/usr/bin/env python3
# coding=utf-8

import os,sys,argparse,re


def select_fields(line, delimiter, fields):
	token_list=line.rstrip("\r\n").split(delimiter)
	out = []
	for arg in fields:
		if type(arg)==int:
			out.append(token_list[arg])
		else:
			out.extend(token_list[arg])
	return delimiter.join(out)

def parse_fields(S):
	if ':' in S:
		return slice(*map(lambda x: int(x) if x else None, S.strip().split(':')))
	return int(S)

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 columns 1>output 2>progress', description='select specific columns in a text file')
	parser.add_argument('columns', help='column indices (uses Python list indexing convention), e.g., 1:3 3:-1 0,2,-2,4:8,3:12:3', nargs='+', default=[])
	parser.add_argument('--delimiter', '-d', help='field delimiter for both input and output, can use \\t for tab', default=None)
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	columns = [parse_fields(j) for i in columns for j in i.split(',')]
	delimiter = delimiter.encode('utf8','ignore').decode('unicode_escape')

	while True:
		try:
			L=input()
		except:
			break
		out = select_fields(L, delimiter, columns)
		print(out, flush=True)



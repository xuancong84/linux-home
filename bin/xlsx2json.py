#!/usr/bin/env python3
# coding=utf-8

import os,sys,argparse,re,json
import pandas as pd
from io import BytesIO


def load_excel(fp):
	return {k:v.to_json() for k,v in pd.read_excel(fp, sheet_name=None).items()}

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [file1 ...] 1>output 2>progress', description='convert Excel file to JSON')
	parser.add_argument('input_files', help='positional argument', nargs='*', default=[])
	parser.add_argument('-optional', help='optional argument')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if input_files:
		obj = {f:load_excel(open(f,'rb')) for f in input_files}
	else:
		obj = load_excel(BytesIO(sys.stdin.buffer.read()))

	print(obj)

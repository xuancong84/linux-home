#!/usr/bin/env python2
# coding=utf-8

import os,sys,argparse,re
from NLP import *


if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 arg1 1>output 2>progress', description='what this program does')
	parser.add_argument('positional', help='positional argument')
	parser.add_argument('-optional', help='optional argument')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	while True:
		try:
			L=raw_input()
		except:
			break
		print L, 'ok'
		sys.stdout.flush()

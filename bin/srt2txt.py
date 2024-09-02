#!/usr/bin/env python3

import os, sys, argparse

sys.path.append(os.path.dirname(__file__))
from NLP import *


def auto_merge(Ls):
	out=[]
	for L in Ls:
		if L.startswith('-') or L.startswith('<'):
			out += [L]
		elif out:
			out[-1] += ' '+L
		else:
			out += [L]
	return out

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [-options] <input-text 1>output 2>progress', description='This converts .srt to .txt, removing indices and timestamps, join multi-line texts.',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('-i', '--input-file', default='-', help='input filename')
	parser.add_argument('-o', '--output-file', default='-', help='output filename')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	lgs = load_linegroups(Open(input_file))
	print(f'INFO: In total, {len(lgs)} line groups.', file=sys.stderr)
	out = [auto_merge(lg[2:]) for lg in lgs]

	save_linegroups(sys.stdout, out)

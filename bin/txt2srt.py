#!/usr/bin/env python3

import os, sys, argparse

sys.path.append(os.path.dirname(__file__))
from NLP import *


if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 [-options] input.srt input.txt 1>output',
								description='This converts .srt to .txt, removing indices and timestamps, join multi-line texts.',
								formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('input_srt', default='-', help='input srt for timestamp')
	parser.add_argument('input_txt', default='-', help='input txt containing subtitle texts')
	parser.add_argument('-o', '--output-file', default='-', help='output filename')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	srt = load_linegroups(input_srt)
	txt = load_linegroups(input_txt)

	if len(srt)!=len(txt):
		raise Exception(f'`{input_srt}` has {len(srt)} time points while `{input_txt}` has {len(txt)} time points')
	
	print(f'INFO: In total, {len(srt)} line groups.', file=sys.stderr)

	out = [lg[:2]+txt[ii] for ii, lg in enumerate(srt)]

	save_linegroups(sys.stdout, out)

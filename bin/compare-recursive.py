#!/usr/bin/env python3
# coding=utf-8

import os, sys, argparse, re, gzip, json
import pandas as pd

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.dirname(__file__) + '/../../feature-processor')
from utils import *
import pandas_serializer as PS

is_df_numeric = lambda df: not df.apply(pd.to_numeric, errors='coerce').isnull().values.any()

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)

def compareDF(df1, df2, f1, f2):
	if df1.columns.to_list() != df2.columns.to_list():
		print(f'DIFF found: {f1} and {f2} have different column names')
		return False
	if df1.index.size == df1.index.size == 0:
		return True
	if df1.index.size != df2.index.size:
		print(f'DIFF found: {f1} and {f2} have different number of rows')
		return False
	if False in df1.index == df2.index:
		print(f'DIFF found: {f1} and {f2} have different row indices')
		return False
	df1a, df2a = df1.fillna(-98765), df2.fillna(-98765)
	diff_mask = df1a!=df2a
	df1b, df2b = df1a[diff_mask].fillna(-98765), df2a[diff_mask].fillna(-98765)
	if not is_df_numeric(df1b) or not is_df_numeric(df2b):
		print(f'DIFF found: {f1} and {f2} have different non-numeric fields')
		return False
	if ((df1b-df2b).abs() > eps).values.any():  # nan != nan, must be replaced for comparison
		print(f'DIFF found: {f1} and {f2} have different value')
		return False
	return True

def compareJSON(o1, o2, f1, f2, level='obj'):
	if type(o1) == dict:
		if type(o2) != dict:
			print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", 1st is a JSON dict while 2nd is not')
			return False
		if o1.keys() != o2.keys():
			print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", 1st has different keys from 2nd: {set(o1.keys())^set(o2.keys())}')
			return False
		res = [compareJSON(o1[k], o2[k], f1, f2, level+f'[{k}]') for k in o1.keys()]
		return False not in res
	elif type(o2) == list:
		if type(o1) != list:
			print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", 1st is a JSON list while 2nd is not')
			return False
		if len(o1) != len(o2):
			print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", len(1st)={len(o1)} while len(2nd)={len(o2)}')
			return False
		res = [compareJSON(o1[i], o2[i], f1, f2, level+f'[{i}]') for i in range(len(o1))]
		return False not in res
	elif type(o1) == pd.DataFrame:
		if type(o2) != pd.DataFrame:
			print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", len(1st)={len(o1)} while len(2nd)={len(o2)}')
			return False
		return compareDF(o1, o2, f1+level[3:], f2+level[3:])
	if type(o1) in [int, float] and type(o2) in [int, float]:
		if isnan(o1) and isnan(o2):
			return True
	res = o1==o2
	if not res:
		print(f'DIFF found: in "{f1}" & "{f2}", at "{level}", {repr(o1)} != {repr(o2)}')
	return res

fn_max, n_files, n_diff = 0, 0, 0
def compareFile(f1, f2):
	global eps, PSON_imported, fn_max, n_files
	fn_max = max(fn_max, len(f1))
	print(f1+' '*(fn_max-len(f1)), end='\r', file=sys.stderr, flush=True)
	n_files += 1
	if '.csv' in f1:
		df1, df2 = load_and_preprocess(f1), load_and_preprocess(f2)
		return compareDF(df1, df2, f1, f2)
	elif '.json' in f1:
		obj1, obj2 = json.load(Open(f1)), json.load(Open(f2))
		return compareJSON(obj1, obj2, f1, f2)
	elif '.pkl' in f1:
		obj1, obj2 = load(f1), load(f2)
		return compareJSON(obj1, obj2, f1, f2)
	elif '.pson' in f1:
		obj1, obj2 = PS.pandas_load(Open(f1)), PS.pandas_load(Open(f2))
		return compareJSON(obj1, obj2, f1, f2)

	# raise Exception('Unknown file type for comparison')
	txt1, txt2 = open(f1, 'rb'), open(f2, 'rb')
	return txt1==txt2


def compare(f1, f2):
	global n_diff
	if os.path.islink(f1):
		res = os.path.realpath(f1) == os.path.realpath(f2)
		if not res:
			print(f'DIFF found: {f1} => {os.path.realpath(f1)} ; however, {f2} => {os.path.realpath(f2)}')
		return res
	if os.path.isdir(f1):
		if not os.path.isdir(f2):
			print(f'DIFF found: {f1} is a folder, but {f2} is not')
			return False
		f1s, f2s = os.listdir(f1), os.listdir(f2)
		diff = set(f1s) ^ set(f2s)
		if diff:
			print(f'DIFF found: {f1} and {f2} contains different files/folders: {diff}')
		res = [compare(f1+'/'+it, f2+'/'+it) for it in (set(f1s)&set(f2s))]
		return np.prod(res+[not diff])
	else:	# is a file
		if not os.path.isfile(f2):
			print(f'DIFF found: {f1} is a file, but {f2} is not')
			return False
		ret = compareFile(f1, f2)
		if not ret:
			n_diff += 1
		return ret


if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='$0 ref-folder tst-folder 1>output 2>progress',
			description='This program recursively compares all files/sub-folders inside two folders.',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('ref', help='reference folder')
	parser.add_argument('tst', help='test output folder')
	parser.add_argument('-e', '--eps', default=1e-5, help='epsilon for floating point comparison')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	print(f'Comparing {ref} vs {tst} ...', file=sys.stderr)
	compare(ref, tst)
	msg = f'Done, in total {n_diff}/{n_files} files are different.'
	fn_max = max(fn_max, len(msg))
	print(msg + ' ' * (fn_max - len(msg)), file=sys.stderr)

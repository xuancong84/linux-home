#!/usr/bin/env python3
# coding=utf-8

import os, sys, io, re, pandas, numpy, gzip, types


def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)


class TC:
	HEADER = '\033[95m'
	OKBLUE = '\033[94m'
	OKGREEN = '\033[92m'
	WARNING = '\033[93m'
	FAIL = '\033[91m'
	ENDC = '\033[0m'
	BOLD = '\033[1m'
	UNDERLINE = '\033[4m'
	END = '\033[0m'
	BLR = '\033[1m\033[91m'
	BLG = '\033[1m\033[92m'
	BLY = '\033[1m\033[93m'
	LR = '\033[91m'
	LG = '\033[92m'
	LY = '\033[93m'


def makedirs(path):
	try:
		os.makedirs(path)
	except:
		pass


try:
	assert type(pandas_sep)==str and len(pandas_sep)
except:
	pandas_sep = ','

# decode pandas objects from strings if found
def pandas_decode(obj, sep=pandas_sep):
	if type(obj) == list:
		return [pandas_decode(i, sep=sep) for i in obj]
	elif type(obj) == tuple:
		return (pandas_decode(i, sep=sep) for i in obj)
	elif type(obj) == set:
		return {pandas_decode(i, sep=sep) for i in obj}
	elif type(obj) == dict:
		return {pandas_decode(k, sep=sep): pandas_decode(v, sep=sep) for k, v in obj.items()}
	elif type(obj) != str:
		return obj
	elif not obj.startswith('\0'):
		return obj
	def safe_eval(s):
		if type(s) == str:
			try:
				return eval(s)
			except:
				pass
		return s
	try:
		obj1 = obj[1:]
		if obj1.startswith("<") and obj1.endswith('>'):
			rem = re.fullmatch("< *([^ ]+) +([^ ]+).*>", obj1.replace('built-in', ''))
			obj_type, obj_name = rem.groups()
			obj2 = eval(obj_name[1:-1] if re.match("'.*'", obj_name) else obj_name)
			obj = obj2 if str(obj1).startswith(obj1.split()[0]) else obj
		else:
			dct = eval(obj1)
			if dct['type'] in ['DataFrame', 'Series']:
				df = pandas.read_csv(io.StringIO(dct['csv']))
				# set column dtypes
				for ii, dt in enumerate(dct['dtypes']):
					if dt == 'object':
						continue
					try:
						df.iloc[:, ii] = df.iloc[:, ii].astype(numpy.dtype(dt))
					except:
						m = re.fullmatch('datetime64\[[^ ]+, *(.*)\]', dt)
						try:
							if m:
								df.iloc[:, ii] = df.iloc[:, ii].astype('datetime64[ns]').dt.tz_localize('utc').dt.tz_convert(m.group(1))
							else:
								df.iloc[:, ii] = df.iloc[:, ii].apply(safe_eval)
						except:
							pass
				df.columns = dct['csv'].splitlines()[0].split(sep)
				df = df.set_index(list(df.columns[:dct.get('index', -1)]))
				obj = df.iloc[:, 0] if dct['type']=='Series' else df
			elif dct['type'] == '<lambda>':
				co = types.CodeType(*dct['code'])
				obj = types.LambdaType(co, globals())
				obj.__defaults__ = dct.get('defaults', None)
				obj.__kwdefaults__ = dct.get('kwdefaults', None)
	except:
		pass
	return obj


# load object from string
def pandas_loads(s, sep=pandas_sep):
	return pandas_decode(eval(s, {'nan':float('nan'), 'array':numpy.array, 'matrix':numpy.matrix}), sep=sep)


# load object from file/filename
def pandas_load(fp, sep=pandas_sep):
	return pandas_loads((fp if hasattr(fp,'read') else Open(fp)).read(), sep=sep)


# encode pandas objects into strings
_convertible_set = {int, float, complex, bool, str, bytes, bytearray, type(None), numpy.ndarray, numpy.matrix}
_get_column_dtype = lambda df: [(('' if len({type(i) for i in v})>1 else 'object') if v.dtype.name=='object' else v.dtype.name) for k,v in df.reset_index().items()]
def pandas_encode(obj, sep=pandas_sep):
	if type(obj) in _convertible_set:
		return obj
	elif type(obj) == list:
		return [pandas_encode(i, sep=sep) for i in obj]
	elif type(obj) == tuple:
		return (pandas_encode(i, sep=sep) for i in obj)
	elif type(obj) == set:
		return {pandas_encode(i, sep=sep) for i in obj}
	elif type(obj) == dict:
		return {pandas_encode(k, sep=sep):pandas_encode(v, sep=sep) for k,v in obj.items()}
	elif type(obj) == pandas.DataFrame:
		return '\0'+str({'type':'DataFrame', 'csv':obj.to_csv(), 'index':len(obj.index.names), 'dtypes':_get_column_dtype(obj)})
	elif type(obj) == pandas.Series:
		return '\0'+str({'type':'Series', 'csv':obj.to_csv(), 'dtypes':_get_column_dtype(obj)})
	elif type(obj) == types.ModuleType:		# must remove file path info to protect privacy
		return "\0<module %s>"%re.fullmatch("<module ([^ >]*)[^>]*>", str(obj)).group(1)
	elif type(obj) == types.LambdaType and obj.__name__==obj.__qualname__=='<lambda>':
		co = obj.__code__
		dct = {'type':'<lambda>',
			   'code':[co.co_argcount,co.co_kwonlyargcount,co.co_nlocals,co.co_stacksize,co.co_flags,co.co_code,co.co_consts,
					co.co_names,co.co_varnames,'',co.co_name,co.co_firstlineno,co.co_lnotab,co.co_freevars,co.co_cellvars],
			   'default':obj.__defaults__,
			   'kwdefault':obj.__kwdefaults__}
		return '\0'+str({k:v for k,v in dct.items() if v is not None})
	return '\0'+str(obj)


# save object to string
def pandas_saves(obj, sep=pandas_sep):
	return repr(pandas_encode(obj))


# save object to file/filename
def pandas_save(obj, fp, sep=pandas_sep):
	(fp if hasattr(fp, 'write') else Open(fp, 'wt')).write(pandas_saves(obj, sep=sep))


# for debugging only
if __name__ == '__main__':
	import pandas as pd
	import numpy as np
	from pandas import concat
	lm = lambda a,b,*args,x=0.5,y=-0.1: a**2+b+sum(args)+x*y+1
	df = pd.DataFrame(np.array(range(16)).reshape([4,4]), columns=['index 1', 'a', 'b', 'c'],
					   index=pd.date_range('2020-01-01', '2020-01-04', tz='tzlocal()')).set_index(['index 1'], append=True)
	df.iloc[1, 0] += 0.5
	df.iloc[1, 1] += 0.5j
	df.iloc[1, 2] = 'abc'
	sr = pd.Series([1, 2.5, 3+1j, np.nan, 'abc', True, None, float], index=pd.date_range('2020-01-01', '2020-01-08', tz='Asia/Singapore'))
	df0 = [1, 3.4, 1.1+2.1j, np.nan, None, True, False, 'abc', b'ab12', bytearray(b'ab12'), int, float,
		   pd.Series(), pd.DataFrame(), pd.DataFrame, type(pd.DataFrame), ['a', 1], lm,
		   {'a':1, 'b':2, type:0, int:1, print:max, pd:np, 0:df, 1:sr, 2:np.array([[1,2.5,'a'],[1+.5j,np.nan,'b']]), 3:np.matrix([[1,2.5],[1+.5j,np.nan]])},
		   {1, 3.4, 1+2j, np.nan, True, False, None, int, 'ab12', os, sys, pd.concat}]

	if True:
		import pyarrow as pa
		buf = pa.serialize([1, 2.5, np.nan, True, False, None, int, float, 'abc', b'asdf', df, sr, {type:float}, lm]).to_buffer()
		df2 = pa.deserialize(buf)
		n_bytes2 = len(buf.to_pybytes())		# Google did an excellent job, but got so many bytes??

	txt = pandas_saves(df0)
	print(txt)
	df1 = pandas_loads(txt)

	n_bytes1 = len(txt.encode('utf8'))

	pandas_save(df0, 'tp.pson.gz')
	df1b = pandas_load('tp.pson.gz')

	assert True
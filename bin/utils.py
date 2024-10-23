import datetime, os, sys, gzip, pickle
import pandas as pd
import numpy as np
from dateutil.tz import tzlocal
from numpy import isnan

def Try(L, alt=None):
	try:
		return L()
	except:
		return alt() if callable(alt) else alt

nan = np.nan
log1p = lambda t: np.log1p(t.astype(float) if hasattr(t, 'astype') else t)
nan_sum = lambda df : df.sum() if len(df.index) else nan
expand_path = lambda t: os.path.expandvars(os.path.expanduser(t))
isdir = lambda t: os.path.isdir(expand_path(t))
listdir = lambda t: sorted(Try(lambda: os.listdir(expand_path(t)), []))
ls_subdir = lambda fullpath: [g.rstrip('/') for f in listdir(fullpath)\
			for g in [expand_path(f'{fullpath}/{f}').replace('//', '/')] if not f.startswith('.') and isdir(g)]

## This set the timezone to local, which is incorrect coz Unix timestamp is always defined to be at UTC-0
# def ms_epoch_to_ts(ms_epoch_ts):
# 	ms_epoch = ms_epoch_ts / 1000  # seconds since epoch time
# 	return ms_epoch.apply(lambda x_: datetime.datetime.fromtimestamp(x_, tz=tzlocal()))

def df_select_cols(df, cols):
	df1 = df.copy()
	for c in cols:
		if c not in df1.columns:
			df1[c] = nan
	return df1[cols]


def ms_epoch_to_ts(ms_epoch_ts):
	dt = pd.to_datetime(ms_epoch_ts, unit='ms', origin='unix', utc=True)
	ret = dt.dt.tz_convert(tzlocal())
	return ret


def group_by_hour(df):
	"""
	:param df: DataFrame with a column 'timestamp' of dtype int containing milliseconds from epoch time
	:return:
	"""
	assert 'timestamp' in df.columns
	assert df['timestamp'].dtype == int

	# group timestamps by hour
	ts_ = ms_epoch_to_ts(df['timestamp'])
	end_hour = ts_.dt.ceil(freq='H')  # the ending hour of the bin into which the timestamp falls
	# end_hour = ts_.ceil('H')

	grouped = end_hour.to_frame(name='end_hour').groupby('end_hour')

	return grouped, ts_, end_hour


def group_by_date(df):
	"""
	:param df: DataFrame with a column 'timestamp' of dtype int containing milliseconds from epoch time
	:return:
	"""
	assert 'timestamp' in df.columns
	assert df['timestamp'].dtype == int

	# group timestamps by day
	ts_ = ms_epoch_to_ts(df['timestamp'])

	# pd.groupby(df['timestamp'].dt.normalize())  # normalize() sets to midnight
	dates = pd.Series([x_.date() for x_ in ts_], name='date')
	grouped = dates.to_frame().groupby(by='date')

	return grouped, ts_, dates


def quantile(obj, Q):
	try:
		return obj.quantile(Q)
	except:
		return []


def apply_frame_from_groupby(df, dfg, col_name, func_names):
	func_names = {col_name+'_'+i:i for i in func_names} if type(func_names)==list else func_names
	if dfg.size().to_list() == []:
		df1 = pd.DataFrame([], columns=[s for s in func_names])
	else:
		df1 = dfg[col_name]
	for out_name, func_name in func_names.items():
		df[out_name] = eval(('df1%s' if func_name.startswith('[') else 'df1.%s()') % func_name)
	return df


def create_frame_from_groupby(dfg, col_name, func_names):
	ret = pd.DataFrame()
	func_names = {col_name+'_'+i:i for i in func_names} if type(func_names)==list else func_names
	if dfg.size().to_list() == []:
		ret = pd.DataFrame([], columns=[s for s in func_names], index=pd.DatetimeIndex([], tz='tzlocal()'))
		ret.index.name = 'datetime'
	else:
		df = dfg[col_name]
		for out_name, func_name in func_names.items():
			ret[out_name] = eval(('df%s' if func_name.startswith('[') else 'df.%s()') % func_name)
	return ret


def create_frame_from_groupby_value_counts(dfg, col_name, cls=None):
	if type(cls) == list:
		selected_cls = cls
	else:
		data0 = dfg.filter(lambda t: True)
		stats = data0[col_name].value_counts()
		N_cls_present = stats.size
		N_cls = N_cls_present if cls is None else min(cls, N_cls_present)
		selected_cls = stats.index.tolist()[:N_cls]
	map_null = lambda t: t if len(t) else {k: 0 for k in selected_cls}
	ret = pd.DataFrame.from_dict({g[0]: map_null(g[1][col_name].value_counts()) for g in dfg}, orient='index')
	ret = ret.fillna(0).sort_index()
	for k in selected_cls:
		if k not in ret.columns:
			ret[k] = 0
	return ret


def create_frame_from_groupby_value_types(dfg, col_name):
	ret = pd.DataFrame.from_dict({g[0]: len(g[1][col_name].value_counts()) for g in dfg}, orient='index')
	ret = ret.fillna(0).sort_index()
	return ret


def create_empty_dataframe(cols_str):
	header = cols_str.split(',')
	return pd.DataFrame(columns=header).set_index(header[0])


def makedirs(path):
	try:
		os.makedirs(path)
	except:
		pass


def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return open(sys.stdin.fileno() if mode.startswith('r') else sys.stdout.fileno(), mode)
	fn = expand_path(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)


def preprocess_df(df: pd.DataFrame):
	if 'timestamp' not in df.columns:
		if df[df.columns[0]].dtype == 'O':
			return df.set_index(df.columns[0])
		df.rename(columns = {df.columns[0]: 'timestamp'}, inplace = True)
		
	# convert timestamp to datetime and set as index
	dt = pd.to_datetime(df['timestamp'], unit = 'ms', origin = 'unix', utc = True)
	df = df.set_index(pd.DatetimeIndex(dt).tz_convert('tzlocal()')).sort_index()

	# remove rows with duplicate timestamp
	df = df.loc[~df.index.duplicated(keep = 'last')]
	df.index.name = 'datetime'
	return df


def load_and_preprocess(fn):
	try:
		df = pd.read_csv(Open(fn), low_memory=False)
	except pd.errors.EmptyDataError:
		return pd.DataFrame()
	return preprocess_df(df)


def add_str_to_fn(fn, s):
	p = fn.rfind('.csv')
	return fn+'.'+s if p<0 else fn[:p+1]+s+fn[p:]


def resolve_zero_vs_nan(df, meta, edge_overflow=0, freq='D', cut_off='auto'):
	key_col = '_COUNT_'
	while key_col in df.columns:
		key_col += '_'
	cut_off = (1 if freq[-1]=='D' else 0) if cut_off=='auto' else cut_off
	f_stamps = pd.to_datetime(sorted(meta), unit='ms', utc=True).tz_convert('tzlocal()')
	df_ = pd.DataFrame([0] * f_stamps.size, index=f_stamps, columns=[key_col])
	df_zero = df_.groupby(pd.Grouper(freq=freq)).count()
	if edge_overflow > 0:
		assert edge_overflow < 0.5, 'setting edge_overflow>=0.5 is not supported'
		dfL = df_.groupby(pd.Grouper(freq=freq, offset=-edge_overflow*pd.to_timedelta('1'+freq))).count()
		dfR = df_.groupby(pd.Grouper(freq=freq, offset= edge_overflow*pd.to_timedelta('1'+freq))).count()
		dfL = dfL.set_index(dfL.index.round(freq))
		dfR = dfR.set_index(dfR.index.round(freq))
		df_zero = pd.concat([dfL, df_zero, dfR], axis=1).fillna(0).max(axis=1).to_frame(key_col)
	ret = df.join(df_zero, how='outer').apply(lambda df1: df1.fillna(0) if df1[key_col]>cut_off else df1+np.nan, axis=1).drop(columns=key_col)
	ret.index.name = df.index.name
	return ret


def save(obj, out_filename):
	with gzip.open(expand_path(out_filename), 'wb') as fp_out:
		pickle.dump(obj, fp_out)


def load(in_filename):
	with gzip.open(expand_path(in_filename), 'rb') as fp_in:
		obj = pickle.load(fp_in)
	return obj


clam_datetime = lambda df: df if df.empty else df[:pd.Timestamp.now(tz='tzlocal()')]


def check_insuff(arr, conds):
	if type(arr) == list:
		arr = pd.Series(arr)
	arr_is_nan = arr.replace('NAN', nan).isna()
	ret = False not in [arr_is_nan[:N].sum()>=n for n, N in conds]
	return True if arr.size<max([max(a) for a in conds]) else ret


def partial_pooling_mean(ser: pd.Series or pd.DataFrame):
	# according to Pg11-12 of https://myweb.uiowa.edu/pbreheny/uk/teaching/701/notes/4-18.pdf
	ser7 = ser.groupby(ser.index.dayofweek)
	assert len(ser7) == 7	# each dayofweek must occur at least once
	mean_all, var_all = ser.mean(), ser.var()
	mean_j = ser7.mean()
	var7 = mean_j.var()
	w_j = Try(lambda: (var7*ser7.count()/(var7*ser7.count()+var_all)).fillna(0.5), 0.5)
	return mean_j*w_j + mean_all*(1-w_j)

pd.Series.pp_mean = pd.DataFrame.pp_mean = partial_pooling_mean

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

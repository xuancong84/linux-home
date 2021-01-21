#!/usr/bin/env python

import os,sys
from numpy import *

arr=[]
for L in sys.stdin:
	for w in L.split():
		try:
			arr+=[float(w)]
		except:
			pass

print 'max=',max(arr)
print 'min=',min(arr)
print 'mean=',mean(arr)
print 'median=',median(arr)
print 'std=',std(arr)
print 'n_total=',len(arr)


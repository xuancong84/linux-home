#!/bin/bash

path="`dirname $0`"

pycode="
import os,sys
import pandas as pd

for L in sys.stdin:
	first=L.split(',')[0]
	if not first.isdigit():
		print(L.strip())
		continue
	tms=pd.Timestamp(int(first), unit='ms' if len(first)==13 else 's', tz='tzlocal()')
	print(str(tms)+','+L.strip())
"

if [ $# -gt 0 ]; then
	zcat -f "$@" | /opt/anaconda3/bin/python -c "$pycode" | less
else
	/opt/anaconda3/bin/python -c "$pycode"
fi


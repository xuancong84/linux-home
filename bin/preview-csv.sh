#!/usr/bin/env bash

if [ $# == 0 ]; then
	echo "Usage: $0 [-first_N_lines] [input_files] ..." >&2
	exit 0
fi

N=200
FS_MAX=100000
if [[ "$1" =~ ^-[0-9]+$ ]]; then
	N=${1:1}
	shift
fi

files=()
for f in "$@"; do
	if [ `stat -c %s "$f"` -ge $FS_MAX ]; then
		sn=`basename "$f" | sed "s:[^a-zA-Z0-9,-]:_:g"`
		tmp=/tmp/$sn.$RANDOM.csv
		zcat -f "$f" | head -N >$tmp
		files+="$tmp"
	else
		tmp="$f"
	fi
	gnumeric $tmp &
done
sleep $#
rm -rf $files


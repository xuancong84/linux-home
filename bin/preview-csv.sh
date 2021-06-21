#!/usr/bin/env bash

if [ $# == 0 ]; then
	echo "Usage: $0 [input_files] ..." >&2
	exit 0
fi

files=()
for f in "$@"; do
	sn=`basename "$f" | sed "s:[^a-zA-Z0-9,-]:_:g"`
	tmp=/tmp/$sn.$RANDOM.csv
	zcat -f "$f" | head -51 >$tmp
	gnumeric $tmp &
	files+="$tmp"
done
sleep $#
rm -rf $files


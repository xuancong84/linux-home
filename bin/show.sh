#!/bin/bash

if [ $# == 1 ]; then
	if echo "$1" | grep '*' 2>1 >/dev/null; then
		echo $1 | sed "s: :\n:g" | while read i; do
			echo \#\#\# $i
			cat $i
			echo
		done
		exit
	fi
fi
if [ $# -ge 1 ]; then
	for i in $*; do
		echo \#\#\# $i
		cat $i
		echo
	done
else
	while read i; do
		echo \#\#\# $i
		cat $i
		echo
	done
fi


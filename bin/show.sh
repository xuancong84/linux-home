#!/bin/bash

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


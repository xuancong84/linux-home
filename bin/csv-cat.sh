#!/bin/bash

a=
while read line; do
	for f in $line; do
		if [ "$a" ]; then
			zcat -f $f | tail --lines=+2
		else
			a=1
			zcat -f $f
		fi
	done
done


#!/bin/bash

mount | grep ntfs | while read line; do
	its=( $line )
	if [ ${its[1]} != on ]; then
		echo "Malformed line: $line"
		echo "2nd word is not 'on'?"
		continue
	fi
	src=${its[0]}
	tgt=${its[2]}
	sudo umount $tgt
	sudo ntfs-3g $src $tgt -olocal -oallow_other
done


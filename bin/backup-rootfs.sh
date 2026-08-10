#!/bin/bash

tgt=ubuntu-rootfs/
if [ "$1" ]; then
	tgt="$1"
fi

cd `dirname $0`

mkdir -p "$tgt"

NOCACHE=
if command -v nocache &>/dev/null; then
	NOCACHE=nocache
fi

DIR=
for d in /bin /boot /etc /lib /lib32 /lib64 /libx32 /opt /root /sbin /usr /var; do
	if [ -d $d ]; then
		DIR="$DIR $d"
	fi
done

$NOCACHE rsync --numeric-ids -avlP --one-file-system --exclude='/var/log' --delete $DIR "$tgt"


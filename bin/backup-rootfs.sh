#!/bin/bash

tgt=ubuntu-rootfs/
if [ "$1" ]; then
	tgt="$1"
fi

cd `dirname $0`

mkdir -p "$tgt"

rsync --numeric-ids -avlP --one-file-system --exclude='/var/log' --delete /bin /boot /etc /lib /lib32 /lib64 /libx32 /opt /root /sbin /usr /var "$tgt"


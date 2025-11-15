#!/bin/bash -e

if [ $# -lt 2 ]; then
	echo "Usage: $0 <src-dir-readonly> <tgt-dir-readwrite> (<USER_ID> <GROUP_ID>)"
	echo "This script will create a read-write version of <src-dir-readonly> on <tgt-dir-readwrite> using overlay mount"
	exit
fi

if [ `whoami` != root ]; then
	sudo $0 "$@" `id -u` `id -g`
	exit
fi

if mountpoint -q "$2"; then
	echo "$2 is already mounted."
	exit
fi

mkdir -p "$2" "$2.upper" "$2.work" "$2.overlay"

mount -t overlay overlay \
	-o lowerdir="$1",upperdir="$2.upper",workdir="$2.work" \
	"$2.overlay"

bindfs -o force-user=$3 -o force-group=$4 "$2.overlay" "$2"

echo "Overlay file-system mounted successfully on $2"
echo -n Press Enter to unmount ...
read

if ! umount "$2"; then
	umount -fl "$2"
fi
if ! umount "$2.overlay"; then
	umount -fl "$2.overlay"
fi


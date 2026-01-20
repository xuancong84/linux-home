#!/bin/bash -e

cd `dirname $0`

if [ "`pwd`" == "/" ]; then
	echo "Error: you are at /"
	echo "Please copy this program to the folder which you want to store your backup."
	exit
fi

mkdir -p media tmp cdrom dev mnt proc run sys
rsync --numeric-ids --one-file-system -avlP --delete /home /bin /boot /opt /root /sbin /snap /usr /etc /lib /var  .


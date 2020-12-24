#!/usr/bin/env bash

echo "`whoami`" "$PWD" "$0" "$1" >/tmp/tp

if [ "$1" ]; then
    res=`udisksctl loop-setup -f $1 | awk '{print $NF}' | sed "s:\.$::g"`
	res=`udisksctl mount -b $res | awk '{print $NF}' | sed "s:\.$::g"`
	xdg-open $res
fi


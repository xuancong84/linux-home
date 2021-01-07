#!/usr/bin/env bash

DID=`xinput | grep Finger | grep -o "id=[0-9]*"`
DID=${DID:3}

res=`xinput list-props $DID | grep 'Device Enabled' | awk '{print $NF}'`

if [ "$res" == 1 ]; then
	xinput disable $DID
else
	xinput enable $DID
fi


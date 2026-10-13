#!/bin/bash

if [ `whoami` != root ]; then
	sudo "$0"
	exit 0
fi

name=
if [ -e /sys/devices/platform/gigabyte_laptop ]; then
	name=gigabyte_laptop
elif [ -e /sys/devices/platform/aorus_laptop ]; then
	name=aorus_laptop
fi

if [ ! "$name" ]; then
	exit
fi

if [ `cat /sys/devices/platform/$name/fan_mode` != 5 ]; then
	echo 75 >/sys/devices/platform/$name/fan_custom_speed
	echo 5 >/sys/devices/platform/$name/fan_mode
	sleep 0.5
	echo 4 >/sys/devices/platform/$name/fan_mode
	sleep 0.5
	echo 75 >/sys/devices/platform/$name/fan_custom_speed
	echo 5 >/sys/devices/platform/$name/fan_mode
else
	echo 4 >/sys/devices/platform/$name/fan_mode
fi


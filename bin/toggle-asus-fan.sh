#!/bin/bash

if [ `whoami` != root ]; then
	sudo $0
	exit
fi

val=`cat /sys/devices/platform/asus-nb-wmi/hwmon/hwmon8/pwm1_enable`

if [ $val == 0 ]; then
	echo 2 >/sys/devices/platform/asus-nb-wmi/hwmon/hwmon8/pwm1_enable
else
	echo 0 >/sys/devices/platform/asus-nb-wmi/hwmon/hwmon8/pwm1_enable
fi


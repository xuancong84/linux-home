#!/bin/bash

if [ `whoami` != root ];then
	echo "This script must be run as root!"
	exit
fi

if [ $# == 0 ];then
	echo "Usage: $0 port_number"
	exit
fi

kill -9 `netstat -tunlp | grep ":$1 " | grep -o '[^ ]*/' | sed "s:/::g"`


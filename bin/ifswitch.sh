#!/usr/bin/env bash

N_fail_limit=5
GWS=("192.168.1.1" "192.168.1.254")

if [ `whoami` != root ]; then
	echo "This script must be run by root!" >&2
	exit
fi

cur_gwi=0
while [ 1 ]; do
	# Wait until losing Internet

	N_fail=0
	while [ 1 ]; do
		if ! ping -W 2 -c 1 8.8.8.8; then
			ping -W 2 -c 1 1.1.1.1
		fi
		if [ $? != 0 ]; then
			N_fail=$[N_fail+1]
			echo "N_fail=$N_fail/$N_fail_limit"
		else
			N_fail=0
		fi
		if [ $N_fail -ge $N_fail_limit ]; then
			break
		fi
		sleep 3
	done

	cur_gwi=$[(cur_gwi+1)%${#GWS[@]}]
	echo "Alert: Gateway is down, switching to ${GWS[cur_gwi]} ..."

	while ip r | grep ^default; do
		route del default
	done
	route add default gw ${GWS[cur_gwi]}

	echo "New routing table is:"
	ip r
done

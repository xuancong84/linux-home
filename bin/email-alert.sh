#!/usr/bin/env bash

N_fail_limit=30

cd "`dirname $0`"

if [ -s secret.sh ]; then
	source secret.sh
fi


while [ 1 ]; do
	echo "Monitoring Computation6 started ..."

	# Monitor whether comp6 is failing
	N_fail=0
	while [ 1 ]; do
		ping -W 2 -c 1 10.8.0.6
		if [ $? != 0 ]; then
			N_fail=$[N_fail+1]
			echo "N_fail=$N_fail/$N_fail_limit"
		else
			N_fail=0
		fi
		if [ $N_fail -ge $N_fail_limit ]; then
			break
		fi
		sleep 5
	done
	echo "Alert: Computation6 is disconnected from VPN!!!"


	# Try to send email alert, and reboot if network fails
	N_fail=0
	while [ 1 ]; do
		ping -W 2 -c 1 8.8.8.8
		if [ $? != 0 ]; then
			N_fail=$[N_fail+1]
			echo "N_fail=$N_fail/$N_fail_limit"
		else
			N_fail=0
			echo "Alert: comp6 disconnected from VPN!" >~/pushNotify
			./email-alert.py
			if [ $? == 0 ]; then
				break
			fi
			sleep 1m
		fi
		if [ $N_fail -ge $N_fail_limit ]; then
			echo "Alert: Network is down, rebooting!!!"
			sudo reboot
		fi
		sleep 5
	done
	echo "Alert: Email alert has been sent out!!!"


	# Wait for comp6 to be back online
	while ! ping -W 2 -c 1 10.8.0.6 ; do
		sleep 5
	done
	echo "Alert: Computation6 is back online!!!"

done

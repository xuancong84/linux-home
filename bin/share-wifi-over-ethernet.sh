#!/usr/bin/env bash

if [ `whoami` != root ]; then
	echo "Error: only root can run this script!" >&2
	exit 1
fi

if [ $# != 2 ]; then
	echo "Usage: $0 source_interface target_interface" >&2
	echo "source_interface has Internet access, this script will share the Internet to target_interface" >&2
	exit 1
fi

src=$1
tgt=$2

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o $src -j MASQUERADE
iptables -A FORWARD -i $src -o $tgt -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $tgt -o $src -j ACCEPT


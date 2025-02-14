#!/bin/bash

if [ $(whoami) != root ];then
	echo "This script must be run as root!"
	exit 1
fi

listname=ipblacklist

ipset -N $listname iphash

wget -O - 'https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_de.ipset' \
	| sed '/^#/d;/^ *$/d' | while read line; do
		ipset add $listname $line  2>/dev/null
	done

iptables -D INPUT -m set --match-set $listname src -j DROP 2>/dev/null
iptables -I INPUT -m set --match-set $listname src -j DROP
iptables -D FORWARD -m set --match-set $listname src -j DROP 2>/dev/null
iptables -I FORWARD -m set --match-set $listname src -j DROP


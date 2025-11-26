#!/usr/bin/env bash

if [ `whoami` != root ]; then
	echo "Error: only root can run this script!" >&2
	exit 1
fi

if [ $# -lt 2 ]; then
	echo "Usage: $0 source_interface target_interface [act=A/D]" >&2
	echo "source_interface has Internet access, this script will share (A) or unshare (D) the Internet to target_interface" >&2
	exit 1
fi

src=$1
tgt=$2
act=${3:-A}

if [ $act == A ]; then
	sysctl -w net.ipv4.ip_forward=1
fi
iptables -t nat -$act POSTROUTING -o $src -j MASQUERADE
iptables -$act FORWARD -i $src -o $tgt -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -$act FORWARD -i $tgt -o $src -j ACCEPT


get_CIDR() {
	ip addr show $1 | grep "inet " | awk '{print $2}'
}
get_netIP() {
	cidr_address=$(get_CIDR $1)
	prefix_length=$(echo "$ip_with_cidr" | cut -d'/' -f2)
	net_address=$(python3 -c "import ipaddress; print(ipaddress.ip_network('$cidr_address', strict=False).network_address)")
	echo "$net_address/$prefix_length"
}

iptables -t nat -$act POSTROUTING -s $(get_netIP $tgt) -d $(get_netIP $src) -j SNAT --to-source $(get_CIDR $src)


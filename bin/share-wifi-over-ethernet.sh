#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 source_interface target_interface [act=A/D]" >&2
    echo "source_interface has Internet/VPN access." >&2
    echo "This script shares (A) or unshares (D) that access to target_interface." >&2
    echo "" >&2
    echo "Example for your case:" >&2
    echo "  $0 tun1 tun0 A" >&2
    exit 1
}

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: only root can run this script!" >&2
    exit 1
fi

if [[ $# -lt 2 ]]; then
    usage
fi

src="$1"
tgt="$2"
act="${3:-A}"

case "$act" in
    A|D) ;;
    *) usage ;;
esac

for iface in "$src" "$tgt"; do
    if ! ip link show dev "$iface" >/dev/null 2>&1; then
        echo "Error: interface '$iface' does not exist" >&2
        exit 1
    fi
done

get_cidr() {
    local iface="$1"
    ip -o -4 addr show dev "$iface" | awk '{print $4; exit}'
}

get_ip() {
    local iface="$1"
    local cidr
    cidr="$(get_cidr "$iface")"

    if [[ -z "$cidr" ]]; then
        echo "Error: interface '$iface' has no IPv4 address" >&2
        exit 1
    fi

    echo "${cidr%/*}"
}

get_net() {
    local iface="$1"
    local cidr
    cidr="$(get_cidr "$iface")"

    if [[ -z "$cidr" ]]; then
        echo "Error: interface '$iface' has no IPv4 address" >&2
        exit 1
    fi

    python3 - "$cidr" <<'PY'
import ipaddress
import sys

print(ipaddress.ip_network(sys.argv[1], strict=False))
PY
}

delete_rule_all() {
    local table="$1"
    local chain="$2"
    shift 2

    while iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do
        iptables -t "$table" -D "$chain" "$@"
    done
}

add_rule_once() {
    local table="$1"
    local chain="$2"
    shift 2

    if ! iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1; then
        iptables -t "$table" -A "$chain" "$@"
    fi
}

insert_rule_at_top() {
    local table="$1"
    local chain="$2"
    shift 2

    # Remove existing copies first so the rule is always placed at the top.
    delete_rule_all "$table" "$chain" "$@"

    iptables -t "$table" -I "$chain" 1 "$@"
}

src_ip="$(get_ip "$src")"
src_net="$(get_net "$src")"
tgt_net="$(get_net "$tgt")"

echo "source interface: $src"
echo "source IP:        $src_ip"
echo "source network:   $src_net"
echo "target interface: $tgt"
echo "target network:   $tgt_net"
echo "action:           $act"

if [[ "$act" == "A" ]]; then
    sysctl -w net.ipv4.ip_forward=1

    # Important: this specific VPN-to-VPN/LAN-to-LAN SNAT rule must be before broader NAT rules.
    insert_rule_at_top nat POSTROUTING \
        -s "$tgt_net" -d "$src_net" -o "$src" \
        -j SNAT --to-source "$src_ip"

    # General NAT for target network going out through source interface.
    add_rule_once nat POSTROUTING \
        -s "$tgt_net" -o "$src" \
        -j MASQUERADE

    # Forward target -> source.
    insert_rule_at_top filter FORWARD \
        -i "$tgt" -o "$src" \
        -j ACCEPT

    # Allow replies source -> target.
    insert_rule_at_top filter FORWARD \
        -i "$src" -o "$tgt" \
        -m conntrack --ctstate RELATED,ESTABLISHED \
        -j ACCEPT

else
    delete_rule_all nat POSTROUTING \
        -s "$tgt_net" -d "$src_net" -o "$src" \
        -j SNAT --to-source "$src_ip"

    delete_rule_all nat POSTROUTING \
        -s "$tgt_net" -o "$src" \
        -j MASQUERADE

    delete_rule_all filter FORWARD \
        -i "$tgt" -o "$src" \
        -j ACCEPT

    delete_rule_all filter FORWARD \
        -i "$src" -o "$tgt" \
        -m conntrack --ctstate RELATED,ESTABLISHED \
        -j ACCEPT
fi


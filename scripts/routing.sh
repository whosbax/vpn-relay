#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

echo "[*] Configuring routing..."

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

ip route flush table "$OVPN_TABLE" || true
ip route add default dev "$OVPN_INTERFACE" table "$OVPN_TABLE"

ip rule del fwmark "$OVPN_MARK" table "$OVPN_TABLE" 2>/dev/null || true
ip rule add fwmark "$OVPN_MARK" table "$OVPN_TABLE"

ipset create ovpn_domains_v4 hash:ip -exist

iptables -t mangle -F
iptables -t mangle -A PREROUTING -i "$WG_INTERFACE" \
    -m set --match-set ovpn_domains_v4 dst \
    -j MARK --set-mark "$OVPN_MARK"

# IPv6 ipset (corporate domains)
ipset create ovpn_domains_v6 hash:ip family inet6 -exist
ip6tables -t mangle -F

ip6tables -t mangle -A PREROUTING -i "$WG_INTERFACE" \
    -m set --match-set ovpn_domains_v6 dst \
    -j MARK --set-mark "$OVPN_MARK"

echo "[✓] Routing OK"
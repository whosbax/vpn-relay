#!/bin/bash
source /opt/vpn-relay/config/params.conf

echo "===== VPN RELAY HEALTH CHECK ====="

echo "[1] Interfaces"
ip a | grep -E "$WG_INTERFACE|$OVPN_INTERFACE"

echo
echo "[2] OpenVPN status"
systemctl is-active openvpn-relay.service

echo
echo "[3] WireGuard"
wg show

echo
echo "[4] ip rule"
ip rule show

echo
echo "[5] Table $OVPN_TABLE"
ip route show table "$OVPN_TABLE"

echo
echo "[6] ipset"
ipset list ovpn_domains_v4

echo
echo "[7] iptables NAT"
iptables -t nat -L -v -n

echo "[8] DNS check"
dig +short @${WG_IPV4%/*} google.com


echo
echo "[✓] Check complete"

#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

echo "[*] Applying firewall rules..."

iptables -F
iptables -t nat -F
iptables -t mangle -F

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp --dport "$WG_PORT" -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i "$WG_INTERFACE" -o "$WAN_INTERFACE" -j ACCEPT
iptables -A FORWARD -i "$WG_INTERFACE" -o "$OVPN_INTERFACE" -j ACCEPT

iptables -t nat -A POSTROUTING -s "$WG_SUBNET_V4" -o "$WAN_INTERFACE" -j MASQUERADE
iptables -t nat -A POSTROUTING -s "$WG_SUBNET_V4" -o "$OVPN_INTERFACE" -j MASQUERADE

# Autoriser DNS pour les clients WireGuard
iptables -A INPUT -i "$WG_INTERFACE" -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i "$WG_INTERFACE" -p tcp --dport 53 -j ACCEPT

ip6tables -A INPUT -i "$WG_INTERFACE" -p udp --dport 53 -j ACCEPT
ip6tables -A INPUT -i "$WG_INTERFACE" -p tcp --dport 53 -j ACCEPT


# ============================================================
# IPv6 Corporate Blocking
# ============================================================

if [ "$IPV6_CORPORATE_MODE" = "block" ]; then
    echo "[*] Blocking IPv6 corporate traffic (no OpenVPN IPv6 support)"

    # Drop marked IPv6 traffic (corporate domains)
    ip6tables -A FORWARD -m mark --mark "$OVPN_MARK" -j DROP
fi

# Allow wg to out default pub gateway 
ip6tables -A FORWARD -i wg0 -j ACCEPT
ip6tables -A FORWARD -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -t nat -A POSTROUTING -s $WG_SUBNET_V6 -o $WAN6_INTERFACE -j MASQUERADE


echo "[✓] Firewall OK"


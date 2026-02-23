#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

echo "[*] Refreshing ipset..."

ipset create ovpn_domains_v4 hash:ip -exist
ipset flush ovpn_domains_v4
ipset create ovpn_domains_v6 hash:ip family inet6 -exist
ipset flush ovpn_domains_v6

resolve_domain() {
    local domain="$1"

    # IPv4 brute
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$domain"
        return
    fi

    # IPv6 brute
    if [[ "$domain" =~ : ]]; then
        echo "$domain"
        return
    fi

    for dns in "${PUBLIC_DNS[@]}"; do
        dig +short A @"$dns" "$domain" 2>/dev/null
        dig +short AAAA @"$dns" "$domain" 2>/dev/null
    done

    for dns in "${VPN_DNS[@]}"; do
        dig +short A @"$dns" "$domain" 2>/dev/null
        dig +short AAAA @"$dns" "$domain" 2>/dev/null
    done
}


for ip in $IPS; do
    if [[ "$ip" == *:* ]]; then
        ipset add ovpn_domains_v6 "$ip" -exist || true
    else
        ipset add ovpn_domains_v4 "$ip" -exist || true
    fi
done


echo "[✓] ipset updated"

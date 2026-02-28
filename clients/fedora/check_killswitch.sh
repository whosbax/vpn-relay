#!/bin/bash
# check_killswitch.sh
# Vérifie routes et kill switch

set -e
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/vpn_killswitch.env"

if [[ -z "$TOR_UID" ]]; then
    TOR_UID=$(id -u "$TOR_USER")
fi

echo "=== Vérification kill switch ==="

echo "[*] Règles ip rule :"
ip rule show

echo "[*] Routes VPN table ($VPN_TABLE) :"
ip route show table "$VPN_TABLE"

echo "[*] Routes Clearnet table ($CLEARNET_TABLE) :"
ip route show table "$CLEARNET_TABLE"

echo "[*] Test IP VPN (IPv4) :"
curl -4 ifconfig.me || echo "[!] Échec"

echo "[*] Test IP VPN (IPv6) :"
curl -6 ifconfig.me || echo "[!] Échec"

echo "[*] Test Tor via SOCKS5 :"
curl --socks5 127.0.0.1:9050 https://check.torproject.org || echo "[!] Tor inaccessible"

echo "=== Vérification terminée ==="
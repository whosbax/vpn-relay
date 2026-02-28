#!/bin/bash
# uninstall_killswitch.sh
# Supprime kill switch et restore routes

set -e
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/vpn_killswitch.env"

if [[ -z "$TOR_UID" ]]; then
    TOR_UID=$(id -u "$TOR_USER")
fi

echo "=== Désinstallation du kill switch ==="

# Supprimer nftables
sudo nft delete table inet killswitch || true

# Supprimer ip rules
sudo ip rule del uidrange "$TOR_UID"-"$TOR_UID" table "$CLEARNET_TABLE" priority "$TOR_PRIORITY" || true
sudo ip rule del from all lookup "$VPN_TABLE" priority "$VPN_PRIORITY" || true

# Supprimer routes tables
sudo ip route flush table "$CLEARNET_TABLE" || true
sudo ip route flush table "$VPN_TABLE" || true

echo "=== Kill switch supprimé ==="
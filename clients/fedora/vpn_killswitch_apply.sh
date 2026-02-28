#!/bin/bash
# vpn_killswitch_apply.sh
# Applique kill switch et split routing (IPv4 + IPv6), safe et idempotent

set -e
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/vpn_killswitch.env"

# --- UID Tor dynamique si vide ---
if [[ -z "$TOR_UID" ]]; then
    TOR_UID=$(id -u "$TOR_USER")
fi
# Attendre que wg0 soit UP
while ! ip link show "$WG_IFACE" | grep -q "UP"; do
    echo "[*] Attente de l'interface WireGuard $WG_IFACE..."
    sleep 1
done
# --- Crée le répertoire /etc/iproute2 et le fichier rt_tables si absent ---
if [[ ! -d /etc/iproute2 ]]; then
    echo "[*] /etc/iproute2 absent, création..."
    sudo mkdir -p /etc/iproute2
fi

if [[ ! -f /etc/iproute2/rt_tables ]]; then
    echo "[*] /etc/iproute2/rt_tables absent, création..."
    sudo touch /etc/iproute2/rt_tables
    sudo chmod 644 /etc/iproute2/rt_tables
fi

# --- Ajouter les tables si elles n'existent pas encore ---
grep -q "$CLEARNET_TABLE" /etc/iproute2/rt_tables || echo "200 $CLEARNET_TABLE" | sudo tee -a /etc/iproute2/rt_tables
grep -q "$VPN_TABLE" /etc/iproute2/rt_tables || echo "201 $VPN_TABLE" | sudo tee -a /etc/iproute2/rt_tables

# --- Routes et ip rules ---
sudo ip route replace default via "$LAN_GW" dev "$LAN_IFACE" table "$CLEARNET_TABLE"
sudo ip rule add uidrange "$TOR_UID"-"$TOR_UID" table "$CLEARNET_TABLE" priority "$TOR_PRIORITY" || true

sudo ip route replace default dev "$WG_IFACE" table "$VPN_TABLE"
sudo ip rule add from all lookup "$VPN_TABLE" priority "$VPN_PRIORITY" || true

# --- Kill switch nftables ---
sudo nft add table inet killswitch || true
sudo nft add chain inet killswitch output '{ type filter hook output priority 0 ; policy drop ; }' || true
sudo nft add rule inet killswitch output oif lo accept || true
sudo nft add rule inet killswitch output oifname "$WG_IFACE" accept || true
sudo nft add rule inet killswitch output meta skuid "$TOR_UID" accept || true
sudo nft add rule inet killswitch output ip daddr "$WG_SERVER_IPV4" udp dport "$WG_PORT" accept || true
sudo nft add rule inet killswitch output ip6 daddr "$WG_SERVER_IPV6" udp dport "$WG_PORT" accept || true


echo "[*] Redémarrage rapide de l'interface WireGuard pour activer les routes..."
sudo ip link set dev "$WG_IFACE" down
sudo ip link set dev "$WG_IFACE" up
sleep 1
echo "[*] Kill switch appliqué avec succès !"
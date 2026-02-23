#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

mkdir -p /etc/wireguard

if [ ! -f /etc/wireguard/server_private.key ]; then
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
fi

PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)

cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
Address = $WG_IPV4, $WG_IPV6
ListenPort = $WG_PORT
PrivateKey = $PRIVATE_KEY
EOF

for client in "${WG_CLIENTS[@]}"; do
    if [ ! -f "$BASE_DIR/keys/${client}_private.key" ]; then
        mkdir -p "$BASE_DIR/keys"
        wg genkey | tee "$BASE_DIR/keys/${client}_private.key" | wg pubkey > "$BASE_DIR/keys/${client}_public.key"
    fi

    CLIENT_PUB=$(cat "$BASE_DIR/keys/${client}_public.key")

    cat >> /etc/wireguard/$WG_INTERFACE.conf <<EOF

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = ${WG_CLIENT_IPV4[$client]}/32, ${WG_CLIENT_IPV6[$client]}/128
EOF
done

systemctl enable wg-quick@$WG_INTERFACE
systemctl restart wg-quick@$WG_INTERFACE

echo "[✓] WireGuard ready"

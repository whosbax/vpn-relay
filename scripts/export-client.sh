#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

CLIENT="$1"
DNS="${WG_IPV4%/*}" 
DNS6="${WG_IPV6%/*}"

SERVER_PUB=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIV=$(cat "$BASE_DIR/keys/${CLIENT}_private.key")

cat > "$BASE_DIR/${CLIENT}.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = ${WG_CLIENT_IPV4[$CLIENT]}/32, ${WG_CLIENT_IPV6[$CLIENT]}/128
DNS = $DNS, $DNS6
PostUp = ip -6 route add default dev %i metric 1024
PreDown = ip -6 route del default dev %i

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${WG_ENDPOINT_HOST}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "[✓] Client config exported to $BASE_DIR/${CLIENT}.conf"

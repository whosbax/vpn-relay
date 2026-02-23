#!/bin/bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[!] Doit être exécuté en root"; exit 1; }

DEV_DIR="$(pwd)"
BASE_DIR="/opt/vpn-relay"

echo "[+] Installation VPN Relay"

# --------------------------------------------------
# 1. Installation des paquets
# --------------------------------------------------

apt update
apt install -y wireguard openvpn ipset iptables curl dnsutils unbound

# --------------------------------------------------
# 2. Désactivation UFW si présent
# --------------------------------------------------

if systemctl is-active --quiet ufw; then
    echo "[+] Désactivation UFW"
    systemctl disable --now ufw
fi

# --------------------------------------------------
# 3. Activation IP forwarding
# --------------------------------------------------

cat >/etc/sysctl.d/99-vpn-relay.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
EOF

sysctl --system

# --------------------------------------------------
# 4. Copie projet vers /opt
# --------------------------------------------------

rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"

cp -r "$DEV_DIR/config" "$BASE_DIR/"
cp -r "$DEV_DIR/scripts" "$BASE_DIR/"
mkdir -p "$BASE_DIR/keys"

chmod +x "$BASE_DIR/scripts/"*.sh

# --------------------------------------------------
# 5. Installer OpenVPN config
# --------------------------------------------------

mkdir -p /etc/openvpn/vpn-relay
cp "$BASE_DIR/config/openvpn/client.ovpn" /etc/openvpn/vpn-relay/
cp "$BASE_DIR/config/openvpn/auth.txt" /etc/openvpn/vpn-relay/

# --------------------------------------------------
# 6. Création service OpenVPN
# --------------------------------------------------

cat >/etc/systemd/system/openvpn-relay.service <<EOF
[Unit]
Description=OpenVPN Relay Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/vpn-relay/client.ovpn
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# 7. Création service VPN Relay principal
# --------------------------------------------------

cat >/etc/systemd/system/vpn-relay.service <<EOF
[Unit]
Description=VPN Relay Routing & Firewall
After=openvpn-relay.service wg-quick@wg0.service
Requires=openvpn-relay.service

[Service]
Type=oneshot
ExecStart=$BASE_DIR/scripts/firewall.sh
ExecStart=$BASE_DIR/scripts/routing.sh
ExecStart=$BASE_DIR/scripts/ipset-refresh.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# 7.1 VPN Timer
# --------------------------------------------------

cat >/etc/systemd/system/vpn-relay.timer <<EOF
[Unit]
Description=Refresh VPN relay ipset

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=vpn-relay.service

[Install]
WantedBy=timers.target
EOF

# --------------------------------------------------
# 8. WireGuard
# --------------------------------------------------

"$BASE_DIR/scripts/wg-server.sh"

# --------------------------------------------------
# Installer Unbound dynamique
# --------------------------------------------------
"$BASE_DIR/scripts/dns-setup.sh"
sleep 2
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# --------------------------------------------------
# 9. Reload systemd
# --------------------------------------------------

systemctl daemon-reload

systemctl enable openvpn-relay.service
systemctl enable vpn-relay.service

systemctl start openvpn-relay.service
sleep 5
systemctl start vpn-relay.service
systemctl enable --now vpn-relay.timer
echo "[✓] Installation terminée"



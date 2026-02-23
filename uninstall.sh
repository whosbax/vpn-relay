#!/bin/bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[!] Doit être exécuté en root"; exit 1; }

echo "[+] Nettoyage complet VPN Relay"

# --------------------------------------------------
# 1. Stop services
# --------------------------------------------------
systemctl stop vpn-relay.timer 2>/dev/null || true
systemctl stop vpn-relay.service 2>/dev/null || true
systemctl stop openvpn-relay.service 2>/dev/null || true
systemctl stop wg-quick@wg0 2>/dev/null || true

# --------------------------------------------------
# 2. Disable services
# --------------------------------------------------
systemctl disable vpn-relay.timer 2>/dev/null || true
systemctl disable vpn-relay.service 2>/dev/null || true
systemctl disable openvpn-relay.service 2>/dev/null || true

# --------------------------------------------------
# 3. Remove systemd unit files
# --------------------------------------------------
rm -f /etc/systemd/system/vpn-relay.service
rm -f /etc/systemd/system/vpn-relay.timer
rm -f /etc/systemd/system/openvpn-relay.service

systemctl daemon-reload

# --------------------------------------------------
# 4. Flush iptables and mangle tables
# --------------------------------------------------
iptables -F
iptables -t nat -F
iptables -t mangle -F

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# --------------------------------------------------
# 5. Remove routing rules and tables
# --------------------------------------------------
ip rule del fwmark 0x1 table 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true

# --------------------------------------------------
# 6. Destroy ipsets
# --------------------------------------------------
ipset destroy ovpn_domains_v4 2>/dev/null || true
ipset destroy ovpn_domains_v6 2>/dev/null || true
ip6tables -F
ip6tables -t mangle -F

# --------------------------------------------------
# 7. Remove WireGuard config and keys
# --------------------------------------------------
rm -f /etc/wireguard/wg0.conf
rm -rf /opt/vpn-relay/keys

# --------------------------------------------------
# 8. Remove OpenVPN configuration
# --------------------------------------------------
rm -rf /etc/openvpn/vpn-relay

# --------------------------------------------------
# 9. Remove project directory
# --------------------------------------------------
rm -rf /opt/vpn-relay

# --------------------------------------------------
# 10. Reset sysctl
# --------------------------------------------------
rm -f /etc/sysctl.d/99-vpn-relay.conf
sysctl --system

echo "[✓] Serveur nettoyé avec succès"

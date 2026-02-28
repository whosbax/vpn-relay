#!/bin/bash
# setup_killswitch.sh
# Installe kill switch + split routing Tor et génère le service systemd dynamique

set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/vpn_killswitch.env"

# UID Tor dynamique si vide
if [[ -z "$TOR_UID" ]]; then
    TOR_UID=$(id -u "$TOR_USER")
fi

echo "=== Installation du kill switch et génération du service systemd ==="
echo "Tor UID = $TOR_UID"

# --- 1. Appliquer kill switch pour cette session ---
"$SCRIPT_DIR/vpn_killswitch_apply.sh"

sudo mkdir -p /opt/vpn-killswitch
sudo cp vpn_killswitch_apply.sh setup_killswitch.sh uninstall_killswitch.sh vpn_killswitch.env /opt/vpn-killswitch/
sudo chmod +x /opt/vpn-killswitch/*.sh

# --- 2. Générer service systemd ---
SERVICE_PATH="/etc/systemd/system/vpn_killswitch.service"
echo "[*] Création du service systemd dynamique à $SERVICE_PATH"

sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Apply WireGuard Kill Switch + Tor split routing
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/vpn-killswitch/vpn_killswitch_apply.sh
ExecStop=/opt/vpn-killswitch/uninstall_killswitch.sh
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

# --- 3. Activer et démarrer le service ---
sudo systemctl daemon-reload
sudo systemctl enable vpn_killswitch.service
sudo systemctl start vpn_killswitch.service

echo "=== Kill switch installé et service systemd actif ==="
#!/bin/bash
# clean_all.sh
# Nettoyage RADICAL - remet le système complètement à zéro
# À utiliser avant tout test pour éliminer les résidus

set -e

echo "=========================================="
echo "  NETTOYAGE RADICAL DU KILL SWITCH"
echo "=========================================="
echo ""
echo "⚠️  Ce script supprime TOUT ce qui a été installé"
echo ""

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/vpn_killswitch.env"

if [[ -z "$TOR_UID" ]]; then
    TOR_UID=$(id -u "$TOR_USER")
fi

# --- 1. Arrêter le service systemd ---
echo "[*] Arrêt du service systemd..."
sudo systemctl stop vpn_killswitch.service 2>/dev/null || true
sudo systemctl disable vpn_killswitch.service 2>/dev/null || true
sleep 1
echo "[✓] Service systemd arrêté"

# --- 2. Supprimer le service systemd ---
echo "[*] Suppression du service systemd..."
sudo rm -f /etc/systemd/system/vpn_killswitch.service
sudo systemctl daemon-reload
echo "[✓] Service systemd supprimé"

# --- 3. Supprimer le dispatcher NetworkManager ---
echo "[*] Suppression du dispatcher NetworkManager..."
sudo rm -f /etc/NetworkManager/dispatcher.d/10-vpn-killswitch-nm-dispatcher.sh
echo "[✓] Dispatcher supprimé"

# --- 4. Supprimer les scripts d'installation ---
echo "[*] Suppression des scripts d'installation..."
sudo rm -rf /opt/vpn-killswitch
echo "[✓] Scripts supprimés"

# --- 5. Supprimer les fichiers de log ---
echo "[*] Suppression des logs..."
sudo rm -f /var/log/vpn-killswitch-dispatcher.log
echo "[✓] Logs supprimés"

# --- 6. Supprimer TOUTES les règles nftables ---
echo "[*] Suppression de toutes les règles nftables..."
if sudo nft list table inet killswitch 2>/dev/null | grep -q "table"; then
    sudo nft delete table inet killswitch
    echo "[✓] Table nftables supprimée"
else
    echo "[✓] Aucune table nftables à supprimer"
fi

# --- 7. Nettoyer TOUTES les règles iproute2 ---
echo "[*] Suppression de TOUTES les règles iproute2..."

# Supprimer toutes les règles avec ces tables
CLEANUP_COUNT=0
# Supprimer toutes les règles clearnet
while ip rule list 2>/dev/null | grep -q "clearnet"; do
    sudo ip rule del lookup clearnet 2>/dev/null || break
    ((CLEANUP_COUNT++))
    if [[ $CLEANUP_COUNT -gt 50 ]]; then
        echo "[!] Limite atteinte pour clearnet"
        break
    fi
done

# Supprimer toutes les règles vpnonly
CLEANUP_COUNT=0
while ip rule list 2>/dev/null | grep -q "vpnonly"; do
    sudo ip rule del lookup vpnonly 2>/dev/null || break
    ((CLEANUP_COUNT++))
    if [[ $CLEANUP_COUNT -gt 50 ]]; then
        echo "[!] Limite atteinte pour vpnonly"
        break
    fi
done

echo "[✓] Règles iproute2 supprimées"

# --- 8. Supprimer les tables de routage ---
echo "[*] Suppression des tables de routage..."
sudo ip route flush table clearnet 2>/dev/null || true
sudo ip route flush table vpnonly 2>/dev/null || true
echo "[✓] Tables de routage vidées"

# --- 9. Nettoyer /etc/iproute2/rt_tables ---
echo "[*] Nettoyage de /etc/iproute2/rt_tables..."
if [[ -f /etc/iproute2/rt_tables ]]; then
    # Supprimer les lignes avec clearnet et vpnonly
    sudo sed -i '/\bclearnet\b/d' /etc/iproute2/rt_tables
    sudo sed -i '/\bvpnonly\b/d' /etc/iproute2/rt_tables
    echo "[✓] Entrées supprimées de rt_tables"
else
    echo "[✓] Fichier /etc/iproute2/rt_tables n'existe pas"
fi

# --- 10. Restaurer la route par défaut ---
echo "[*] Restauration de la route par défaut du système..."

# Récupérer la passerelle par défaut depuis NetworkManager
DEFAULT_GW=$(ip route show table main | grep ^default | awk '{print $3}')
DEFAULT_IFACE=$(ip route show table main | grep ^default | awk '{print $5}')

if [[ -n "$DEFAULT_GW" ]] && [[ -n "$DEFAULT_IFACE" ]]; then
    # Supprimer TOUTES les routes par défaut dans la main table
    while ip route show table main | grep -q "^default"; do
        sudo ip route del default 2>/dev/null || break
    done

    # Réajouter la route par défaut correcte
    sudo ip route add default via "$DEFAULT_GW" dev "$DEFAULT_IFACE"
    echo "[✓] Route par défaut restaurée: via $DEFAULT_GW dev $DEFAULT_IFACE"
else
    echo "[!] Impossible de déterminer la route par défaut"
fi

# --- 11. Vérification finale ---
echo ""
echo "=========================================="
echo "  VÉRIFICATION DU NETTOYAGE"
echo "=========================================="
echo ""

echo "Règles iproute2 restantes:"
ip rule list | grep -v "^0:\|^32766:\|^32767:" || echo "  (aucune règle anormale)"

echo ""
echo "Règles nftables:"
if sudo nft list table inet killswitch 2>/dev/null; then
    echo "  ✗ ERREUR: Table nftables toujours présente!"
else
    echo "  ✓ Aucune table nftables"
fi

echo ""
echo "Route par défaut:"
ip route show table main | grep ^default

echo ""
echo "=========================================="
echo "✅ NETTOYAGE TERMINÉ"
echo "=========================================="
echo ""
echo "Le système est now complètement vierge."
echo "Vous pouvez maintenant relancer l'installation depuis zéro."
echo ""

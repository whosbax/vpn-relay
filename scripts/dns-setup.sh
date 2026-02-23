#!/bin/bash
set -e
source /opt/vpn-relay/config/params.conf

echo "[*] Installing and configuring Unbound DNS dynamically..."

# Fichier de config spécifique
UNBOUND_CONF="/etc/unbound/unbound.conf.d/vpn-relay.conf"
WG_IPV4_ONLY=$(echo "$WG_IPV4" | cut -d'/' -f1)
WG_IPV6_ONLY=$(echo "$WG_IPV6" | cut -d'/' -f1)
cat >"$UNBOUND_CONF" <<EOF
server:
    interface: $WG_IPV4_ONLY
    interface: $WG_IPV6_ONLY
    interface: 127.0.0.1
    interface: ::1    
    access-control: $WG_SUBNET_V4 allow
    access-control: $WG_SUBNET_V6 allow
    access-control: 127.0.0.0/8 allow
    verbosity: 1
    do-not-query-localhost: no
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
EOF

# Extraire les zones depuis domains.txt
declare -A zones
while read -r domain; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    # Si c'est une IP, ignorer pour Unbound
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        continue
    fi

    suffix=$(echo "$domain" | awk -F. '{print $(NF-1)"."$NF}')
    zones["$domain"]=1
    if [[ "$domain" != "$suffix" ]]; then
        zones["$suffix"]=1
    fi
done < "$DOMAIN_FILE"
# Forward par défaut pour le reste
cat >>"$UNBOUND_CONF" <<EOF
forward-zone:
    name: "."
EOF
for dns in "${PUBLIC_DNS[@]}"; do
    echo "    forward-addr: $dns" >> "$UNBOUND_CONF"
done
for dns in "${PUBLIC_DNS6[@]}"; do
    echo "    forward-addr: $dns" >> "$UNBOUND_CONF"
done

# Ajouter des forward-zones pour chaque suffixe
for z in "${!zones[@]}"; do
    echo "forward-zone:" >> "$UNBOUND_CONF"
    echo "    name: \"$z\"" >> "$UNBOUND_CONF"
    for dns in "${VPN_DNS[@]}"; do
        echo "    forward-addr: $dns" >> "$UNBOUND_CONF"
    done
done


# Redémarrer Unbound
systemctl enable unbound
systemctl restart unbound

echo "[✓] Unbound configured on $WG_IPV4 for WireGuard clients"

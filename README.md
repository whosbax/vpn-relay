
# VPN Relay – WireGuard + OpenVPN + Domain-Based Split Routing

Un projet permettant de déployer un **serveur VPN multi-tunnel** qui :

* fournit un accès VPN général via **WireGuard**,
* relaye une partie du trafic sélectionné (par domaines ou IP) vers un second tunnel **OpenVPN**,
* effectue du **split tunneling basé sur la destination** (policy-based routing),
* offre un DNS sécurisé et une politique NAT/firewall robuste.

Ce système est particulièrement utile si tu veux :

* chiffrer tout le trafic client vers ta VM/serveur VPN via WireGuard,
* **diriger uniquement certains flux ciblés vers un VPN supplémentaire** (par exemple vers un VPN corporate) en fonction des domaines/IPs listés,
* éviter les fuites DNS pour les clients VPN,
* maintenir un routage propre et automatisé même quand les IP associées aux domaines changent.

---

## 🧠 Principes de fonctionnement

```
[ VPN Client (WireGuard) ]
             ↓
     [ VPN-Relay Server ]
       ↙︎          ↘︎
  Internet      OpenVPN Tunnel
                (traffic for selected destinations)
```

1. Les clients se connectent via **WireGuard**.
2. Le serveur utilise une **liste déclarative de domaines/IPs** pour déterminer quels trafics doivent être routés **via le tunnel OpenVPN**.
3. Les autres flux (non listés) continuent par défaut vers Internet classique via le NAT/routeur.
4. Un système d’**ipset + iptables/ip rule** effectue un routage basé sur des marques (policy-based routing) pour trier le trafic.
5. Un **résolveur DNS (Unbound)** assure l’absence de fuites DNS.

Ce projet est un exemple de split tunneling *par destination* (policy-based split tunneling) plutôt que par application ou par source. ([wiresock.net][1])

---

## 📁 Structure du projet

```
vpn-relay/
├── config/
│   ├── domains.txt              # Liste des domaines/IP à router via OpenVPN
│   ├── params.conf              # Configuration globale (interfaces, IPs, DNS, etc.)
│   └── openvpn/
│       ├── client.ovpn          # Fichier de configuration OpenVPN
│       └── auth.txt             # Identifiants pour OpenVPN
├── scripts/
│   ├── firewall.sh              # Applique règles iptables
│   ├── routing.sh               # Configure routing table et mark
│   ├── ipset-refresh.sh         # Résolution de domaines et refresh de l’ipset
│   ├── export-client.sh         # Génère config WireGuard par client
│   ├── wg-server.sh             # Génère clés et WireGuard server config
│   ├── dns-setup.sh             # Installe / configure Unbound pour DNS sécurisé
│   └── health-check.sh          # Outil d’audit/diagnostic
├── install.sh                   # Script d’installation automatisée
├── uninstall.sh                 # Script de suppression complète
└── README.md                    # Documentation du projet
```

---

## ⚙️ Principales fonctionnalités

### 🛡️ VPN hybride

* **WireGuard** pour les connexions VPN des clients – léger, performant, support IPv4/IPv6.
* **OpenVPN** en tant que *relay* pour une destination nommée ou un regroupement d’adresses IP.

### 🔀 Routage conditionnel (split routing)

La liste dans `config/domains.txt` détermine quels flux doivent être envoyés via OpenVPN.
Un ensemble d’IP est construit dynamiquement à partir des domaines et utilisée dans des règles de marquage (`iptables mangle + ipset`).
Le trafic marqué est ensuite routé via une table de routage dédiée pour l’OpenVPN.

Ce comportement constitue un **split tunneling basé sur la destination** (policy based routing). ([Class Central][2])

---

## 📥 Installation

> Requis : une distribution Debian/Ubuntu récente (par ex. Debian 12+, Ubuntu 22.04+)

1. Clone le dépôt :

   ```bash
   git clone <repo_url> /opt/vpn-relay
   cd /opt/vpn-relay
   ```

2. Lance l’installateur :

   ```bash
   sudo ./install.sh
   ```

3. Le script :

   * installe les paquets requis (`wireguard`, `openvpn`, `ipset`, `iptables`, `unbound`, etc.)
   * configure les règles système et firewall
   * installe et active les services systemd
   * génère les clés et configurations WireGuard
   * déploie le DNS local avec Unbound

---

## 📡 Configuration VPN Clients

Les clients WireGuard sont définis dans `config/params.conf` :

* Public IP du serveur, interfaces,
* Sous-réseaux assignés,
* Adresse IPv4/IPv6 par client.

La génération de la configuration cliente se fait avec :

```bash
./scripts/export-client.sh client1
```

Le fichier `.conf` généré se trouve sous `/opt/vpn-relay/client1.conf` et peut être importé dans un client WireGuard.

---

## 📜 Mise à jour automatique des IPs

Un systemd **timer** exécute régulièrement :

```bash
ipset-refresh.sh
```

Ce script résout les domaines de `domains.txt` et met à jour les ensembles IP (`ipset`) utilisés pour le routage.
Il garantit que les changements d’IP derrière des domaines routés ne cassent pas la politique de routage.

---

## 🧪 Outils de vérification / santé

Tu peux exécuter :

```bash
./scripts/health-check.sh
```

Ce script affiche :

* Statut des interfaces
* État des tunnels VPN
* Tables de routage
* Listes ipset
* Débogage DNS

---

## 🧠 Sécurité

* Le firewall est strict par défaut : politiques DROP sur INPUT et FORWARD.
* NAT est appliqué pour les clients WireGuard afin d’assurer un trafic Internet fonctionnel.
* Le routage vers OpenVPN est isolé via marquage et une table de routage spécifique.
* DNS sécurisé via **Unbound** pour éviter les fuites au-delà du tunnel VPN.

---

## 🧨 Désinstallation

Pour tout supprimer proprement :

```bash
sudo ./uninstall.sh
```

Il arrêtera les services, restaurera les politiques réseau par défaut et supprimera tous les fichiers liés.

---

## 🧾 Bonnes pratiques

* Ajoute **seulement des domaines ou IP explicites** dans `config/domains.txt`.
* Vérifie régulièrement les règles iptables et ipset après modifications.
* Teste la résolution DNS et le routage avec `dig` ou `traceroute` depuis un client WireGuard.
* Versionne le fichier `config/params.conf` (sans les clés privées) dans ton dépôt protégé.

---

## 🏷️ LICENSE

Licencie ce projet selon le modèle de ton choix (MIT, Apache 2.0, GPL, etc.).

---

## 📚 Références

Ce type de routage conditionnel est une variante de ce que l’on appelle **split tunneling ou policy-based routing**, permettant de router seulement certains flux via un tunnel VPN tout en laissant le reste utiliser d’autres routes réseau. ([wiresock.net][1])

---
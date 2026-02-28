
## VPN Kill Switch — Fedora 43

### Description
* Kil Switch WireGuard + split routing Tor (IPv4/IPv6)  
* Persistance automatique via service systemd.

---
### Prérequis

- Personnaliser le fichier de configuration `.env` à partir de l’exemple fourni :  
```bash
cp vpn_killswitch.example.env vpn_killswitch.env
```
### Commandes
#### Installer / Setup / Check / Rollback
```bash
# install
chmod +x vpn_killswitch_apply.sh setup_killswitch.sh
./setup_killswitch.sh

# check
chmod +x check_killswitch.sh
./check_killswitch.sh

# rollback
sudo systemctl stop vpn_killswitch.service
sudo systemctl disable vpn_killswitch.service
./uninstall_killswitch.sh
````

---

#### Traffic Routing & Kill Switch Overview

```
           ┌─────────────┐
           │   Internet  │
           └─────┬──────┘
                 │
         ┌───────┴────────┐
         │      LAN       │  (ex: Wi-Fi)
         └───────┬────────┘
                 │
        ┌────────┴──────-────┐
        │ nftables KillSwitch│
        │   Policy: DROP     │
        │   Exceptions:      │
        │   - wg0 (VPN)      │
        │   - lo             │
        │   - UID toranon    │
        │   - WG server IP   │
        └────────┬───-───────┘
                 │
   ┌─────────────┴─────────────────────┐
   │                                   │
┌──▼─────────────┐           ┌─────────▼────────┐
│  VPN           |           │  Tor             │
│ Table          |           │ Table            │
│ vpnonly        |           │ clearnet         │
│ Dev: wg0       |           │ Dev: wlp194s0    │
│ Default route  |           │ UID toranon only │
│ Non-Tor traffic|           │ Tor traffic only │
└────────────────┘           └──────────────────┘
```
---

### Legend

* **VPN Table**: all traffic except Tor goes via WireGuard. Dropped if VPN down.
* **Tor Table**: traffic from `toranon` only, goes via LAN/Wi-Fi, bypasses VPN.
* **KillSwitch**: blocks all other traffic, preventing IP leaks.



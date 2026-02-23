Here is the cleaned version of your `README.md` without emojis.

---

# Docker NordVPN Gateway

This project creates a Docker-based VPN Gateway using NordVPN.

The container:

* Connects to NordVPN (WireGuard / NordLynx by default)
* Acts as a gateway for your LAN
* Applies NAT (MASQUERADE) via the VPN tunnel
* Enforces a kill-switch using iptables
* Prevents traffic leaks to WAN

---

# Project Structure

```
/opt/vpn/
│
├── docker-compose.yml
├── .env
└── nordvpn/
    ├── Dockerfile
    └── entrypoint.sh
```

---

# Configuration

Edit the `.env` file:

```
# ==========================
# NordVPN Configuration
# ==========================

NORD_TOKEN=enter_your_token_here
VPN_COUNTRY=Germany

# ==========================
# LAN Network Configuration
# ==========================

LAN_IP=192.168.254.254
LAN_SUBNET=192.168.254.0/24
LAN_INTERFACE=ens224

# ==========================
# WAN Network Configuration
# ==========================

WAN_IP=10.10.10.254
WAN_SUBNET=10.10.10.0/24
```

---

## Variable Explanation

### NordVPN

| Variable    | Description              |
| ----------- | ------------------------ |
| NORD_TOKEN  | Your NordVPN login token |
| VPN_COUNTRY | Country to connect to    |

### LAN

| Variable      | Description                |
| ------------- | -------------------------- |
| LAN_IP        | Gateway IP used by clients |
| LAN_SUBNET    | Local network subnet       |
| LAN_INTERFACE | Physical LAN NIC on host   |

Clients must use:

```
Gateway: 192.168.254.254
DNS: your choice (or leave empty if gateway handles it)
```

### WAN

| Variable   | Description              |
| ---------- | ------------------------ |
| WAN_IP     | Docker WAN bridge IP     |
| WAN_SUBNET | Docker WAN bridge subnet |

---

# Start the Gateway

```
docker compose up -d --build --force-recreate
```

Check logs:

```
docker logs -f nordvpn
```

You should see:

```
You are connected to Germany #xxxx
```

---

# Verify Routing

From a LAN client:

```
ping 1.1.1.1
curl -4 ifconfig.io
```

You should see a NordVPN public IP, not your ISP IP.

---

# Security Model

The container:

* Drops all traffic by default
* Only allows:

  * LAN → VPN
  * VPN → LAN (established connections)
  * Required NordVPN bootstrap traffic
* Blocks LAN → WAN directly
* NATs only through `nordlynx`

---

# Debugging

Enter container:

```
docker exec -it nordvpn bash
```

Check:

```
ip a
ip route
iptables -L -v -n
iptables -t nat -L -v -n
```

Monitor VPN tunnel:

```
tcpdump -nni nordlynx
```

---

# Important Notes

* Do not use `network_mode: host`
* Ensure the host does not have `192.168.254.254/24` configured on the same LAN interface
* macvlan requires the LAN interface to be correct (`LAN_INTERFACE`)
* If container removal fails with a `resolv.conf immutable` error, restart Docker:

```
systemctl restart docker
```

---

# Traffic Flow

```
LAN Client
   ↓
Docker macvlan (192.168.254.254)
   ↓
iptables NAT
   ↓
NordLynx (nordlynx)
   ↓
Internet via NordVPN
```
#!/bin/bash

# Start NordVPN Daemon
/usr/sbin/nordvpnd > /var/log/nordvpn.log 2>&1 &

# Wait for the daemon socket to exist
echo "Waiting for NordVPN daemon..."
while [ ! -S /run/nordvpn/nordvpnd.sock ]; do sleep 1; done

# Setup NordVPN parameters
nordvpn set analytics disable
nordvpn set technology NordLynx
nordvpn set protocol udp
nordvpn set killswitch on 

# Login and Connect
echo "Connecting to NordVPN..."
nordvpn login --token "${NORD_TOKEN}"
nordvpn connect "${VPN_COUNTRY}"

# NAT Routing (The Gateway part)
echo "Enabling NAT routing..."
WAN_IF="$(ip route | awk '/default/ {print $5; exit}')"
VPN_IF=$(ip addr | grep -oE '(tun0|nordtun|nordlynx)' | head -n1)
LAN_IF="$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.1\./ {print $2; exit}')"

# --- reset ---
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# --- default deny (killswitch) ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# --- basic ---
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Established/Related
iptables -A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- allow LAN to talk to the gateway itself (container IP 192.168.1.254) ---
iptables -A INPUT -i "$LAN_IF" -s "$LAN_SUBNET" -j ACCEPT

# --- DNS (bootstrap) ---
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 53 -j ACCEPT

# --- HTTPS (bootstrap for login/API + certificate checks) ---
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 80  -j ACCEPT

# --- VPN bootstrap ports ---
# OpenVPN typical
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 1194 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 443  -j ACCEPT

# NordLynx/WireGuard/OpenVPN: don't over-tighten unless you KNOW exact port
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 51820:51900 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 1194 -j ACCEPT

# --- allow VPN traffic once the tunnel exists ---
if [ -n "$VPN_IF" ]; then
  iptables -A OUTPUT -o "$VPN_IF" -j ACCEPT
fi

# --- anti-leak: block anything else via WAN ---
iptables -A OUTPUT  -o "$WAN_IF" -j REJECT
iptables -A FORWARD -i "$LAN_IF" -o "$WAN_IF" -j REJECT

# =========================================================
# ===================== YOUR 3 RULES ======================
# ===================== (AT THE END) ======================
# =========================================================

# NAT out via VPN tunnel
iptables -t nat -A POSTROUTING -s "$LAN_SUBNET" -o "$VPN_IF" -j MASQUERADE

# Allow LAN -> VPN
iptables -A FORWARD -i "$LAN_IF" -o "$VPN_IF" -j ACCEPT

# Allow VPN -> LAN replies
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

echo "Streaming logs..."
exec tail -f /var/log/nordvpn.log
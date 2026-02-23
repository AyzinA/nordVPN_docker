FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl gnupg iptables iproute2 procps \
    iputils-ping dnsutils net-tools vim tcpdump

# Enable IP forwarding
RUN echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# Create the directories the daemon needs
RUN mkdir -p /run/nordvpn /var/lib/nordvpn /var/log/nordvpn

# Install NordVPN
RUN apt-get update && \
apt-get install -y --no-install-recommends wget apt-transport-https ca-certificates && \
    apt-get install -y --no-install-recommends wget apt-transport-https ca-certificates && \
    wget -qO /etc/apt/trusted.gpg.d/nordvpn_public.asc https://repo.nordvpn.com/gpg/nordvpn_public.asc && \
    echo "deb https://repo.nordvpn.com/deb/nordvpn/debian stable main" > /etc/apt/sources.list.d/nordvpn.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nordvpn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s \
    CMD nordvpn status | grep -q "Status: Connected" || exit 1

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

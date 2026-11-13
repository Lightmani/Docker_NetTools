#!/bin/bash

#===============================================================================================
#   Xray & Caddy v2 One-Click Deployment Script for Debian 12/13
#   Version: 3.0 (Fixed x25519 parser, IPv6 dual-stack, h2c socket, and 500Mbps+ sysctl)
#===============================================================================================

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

GENERATED_UUID=$(cat /proc/sys/kernel/random/uuid)
SS_PASS=$(openssl rand -base64 32)
SHORT_ID=$(openssl rand -hex 8)

print_step() {
    echo -e "${YELLOW}=======================================================${NC}"
    echo -e "${YELLOW} STEP: $1${NC}"
    echo -e "${YELLOW}=======================================================${NC}"
}

print_success() { echo -e "${GREEN}✔ $1${NC}"; }
print_error() { echo -e "${RED}✘ $1${NC}"; exit 1; }

#--- [1. Pre-flight Checks] ---
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root. Please use 'sudo -i' first."
fi

if ! grep -qE 'VERSION_ID="(12|13)"' /etc/os-release; then
    print_error "This script is designed for Debian 12 (Bookworm) or Debian 13 (Trixie)."
fi

#--- [2. User Input] ---
print_step "Getting User Input"
read -p "Please enter your domain name (e.g., xray.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain name cannot be empty."
fi
echo -e "${YELLOW}Ensure '$DOMAIN' A/AAAA records point to this server's public IP.${NC}"
read -p "Press [Enter] to continue..."
print_success "Domain set to: $DOMAIN"

#--- [3. System Update & Dependencies] ---
print_step "Updating System and Installing Dependencies"
apt update && apt upgrade -y
apt install -y curl wget socat git ca-certificates gnupg cron sudo openssl || print_error "Failed to install dependencies."
apt remove --purge nginx nginx-full nginx-common -y 2>/dev/null
print_success "System updated and dependencies installed."

#--- [4. Firewall Configuration] ---
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    print_step "Configuring Firewall"
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw allow 8443/tcp
    ufw allow 52666/tcp
    ufw allow 52666/udp
    ufw reload
    print_success "Firewall ports 22, 80, 443(TCP/UDP), 8443(TCP), 52666(TCP/UDP) opened."
fi

#--- [5. Install & Configure Caddy v2] ---
print_step "Installing and Configuring Caddy v2"
ARCH=$(dpkg --print-architecture)
CADDY_VER=$(curl -fsSL https://api.github.com/repos/caddyserver/caddy/releases/latest | grep -Po '"tag_name": "\K[^"]+' || echo "v2.10.0")
CADDY_NUM=${CADDY_VER#v}
wget -O /opt/caddy.deb "https://github.com/caddyserver/caddy/releases/download/${CADDY_VER}/caddy_${CADDY_NUM}_linux_${ARCH}.deb" || print_error "Failed to download Caddy."
apt install -y /opt/caddy.deb || print_error "Failed to install Caddy."
rm -f /opt/caddy.deb

mkdir -p /var/www/html
if [ ! -f /var/www/html/index.html ]; then
    echo "Welcome to my website!" > /var/www/html/index.html
fi

cat <<EOF > /etc/caddy/Caddyfile
${DOMAIN} {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    # Reverse proxy XHTTP traffic on /download/* via HTTP/2 cleartext (h2c)
    handle /download/* {
        reverse_proxy unix//dev/shm/Xray-VLESS-XHTTP.socket {
            transport http {
                versions h2c 1.1
                read_timeout 315s
                write_timeout 5m
            }
            header_up Host {http.request.host}
        }
    }

    # Serve camouflage website for normal visits & REALITY fallbacks
    handle {
        root * /var/www/html
        file_server
    }
}
EOF
print_success "Caddy ${CADDY_VER} (${ARCH}) installed and configured."

#--- [6. Install & Configure Xray-core] ---
print_step "Installing Xray-core"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install || print_error "Xray installation failed."
print_success "Xray-core installed."

print_step "Configuring Xray"
KEY_OUT=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEY_OUT" | awk -F': ' '/Private/ {print $2}' | tr -d ' \r')
PUBLIC_KEY=$(echo "$KEY_OUT" | awk -F': ' '/Public|Password/ {print $2}' | tr -d ' \r')

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    print_error "Failed to parse x25519 keys from Xray output:\n$KEY_OUT"
fi

mkdir -p /etc/v2ray
cat <<EOF > /etc/v2ray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      "tcp+local://8.8.8.8:53"
    ]
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${GENERATED_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "127.0.0.1:443",
          "xver": 0,
          "serverNames": [
            "${DOMAIN}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    },
    {
      "tag": "vless-xhttp-uds",
      "listen": "/dev/shm/Xray-VLESS-XHTTP.socket,0666",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${GENERATED_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "auto",
          "path": "/download/"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    },
    {
      "tag": "ss-ipv6-direct",
      "listen": "::",
      "port": 52666,
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "${SS_PASS}",
        "network": "tcp,udp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "AsIs"
      }
    },
    {
      "tag": "stream",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "domain": [
          "geosite:netflix",
          "geosite:category-ai-!cn"
        ],
        "outboundTag": "stream"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

rm -f /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json

# Ensure stale Unix socket is cleaned up before Xray starts
mkdir -p /etc/systemd/system/xray.service.d
cat <<EOF > /etc/systemd/system/xray.service.d/override.conf
[Service]
ExecStartPre=-/bin/rm -f /dev/shm/Xray-VLESS-XHTTP.socket
LimitNOFILE=1000000
EOF
print_success "Xray configuration created and verified."

#--- [7. System & Network Tuning (500Mbps+ BBR)] ---
print_step "Optimizing System Parameters (sysctl, limits)"
cat <<EOF > /etc/sysctl.d/99-xray-tuning.conf
fs.file-max = 1000000
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF
sysctl --system >/dev/null

cat <<EOF > /etc/security/limits.d/99-xray.conf
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
systemctl daemon-reload
print_success "System parameters optimized."

#--- [8. Start Services] ---
print_step "Starting Services"
systemctl enable caddy xray
systemctl restart caddy
systemctl restart xray

/usr/local/bin/xray run -test -c /usr/local/etc/xray/config.json || print_error "Xray config test failed!"
print_success "Caddy and Xray started successfully."

#--- [9. Display Configuration] ---
print_step "Deployment Complete! Connection Details:"
echo -e "-------------------------------------------------------"
echo -e "  ${GREEN}[1] VLESS + RAW + Vision + REALITY (Primary)${NC}"
echo -e "  Address (地址):      ${DOMAIN}"
echo -e "  Port (端口):         8443"
echo -e "  UUID:                ${GENERATED_UUID}"
echo -e "  Flow (流控):         xtls-rprx-vision"
echo -e "  SNI:                 ${DOMAIN}"
echo -e "  PublicKey (公钥):    ${PUBLIC_KEY}"
echo -e "  ShortId:             ${SHORT_ID}"
echo -e "-------------------------------------------------------"
echo -e "  ${GREEN}[2] VLESS + XHTTP + TLS (CDN / Backup)${NC}"
echo -e "  Address (地址):      ${DOMAIN}"
echo -e "  Port (端口):         443"
echo -e "  UUID:                ${GENERATED_UUID}"
echo -e "  Transport (传输):    xhttp (auto)"
echo -e "  Path (路径):         /download/"
echo -e "  TLS:                 tls (SNI: ${DOMAIN})"
echo -e "-------------------------------------------------------"
echo -e "  ${GREEN}[3] Shadowsocks-2022 (IPv6 / Dual-Stack Direct)${NC}"
echo -e "  Listen (监听):       :: (IPv6 & IPv4)"
echo -e "  Port (端口):         52666"
echo -e "  Method (加密):       2022-blake3-aes-256-gcm"
echo -e "  Password (密码):     ${SS_PASS}"
echo -e "-------------------------------------------------------"

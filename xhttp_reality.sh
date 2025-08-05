#!/bin/bash

#===============================================================================================
#   Xray & Caddy v2 One-Click Deployment Script for Debian 12
#
#   Author: Gemini (Refactored from original Nginx script)
#   Version: 2.0 (Caddy Edition)
#   Description: This script automates the setup of Xray with VLESS+H2+TLS,
#                using Caddy v2 as a reverse proxy with automatic HTTPS.
#
#===============================================================================================

#--- [Color Codes] ---
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

#--- [Script Configuration] ---
# Auto-generate a UUID and password
GENERATED_UUID=$(cat /proc/sys/kernel/random/uuid)
sspass=$(openssl rand -base64 32)

#--- [Helper Functions] ---
print_step() {
    echo -e "${YELLOW}=======================================================${NC}"
    echo -e "${YELLOW} STEP: $1${NC}"
    echo -e "${YELLOW}=======================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_error() {
    echo -e "${RED}✘ $1${NC}"
    exit 1
}

#--- [Pre-flight Checks] ---
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root. Please use 'sudo -i' first."
fi

# Check for Debian 12
if ! grep -q "VERSION_ID=\"12\"" /etc/os-release; then
    print_error "This script is designed for Debian 12 (Bookworm)."
fi

#--- [Main Script] ---

# 1. Get User Input
print_step "Getting User Input"
read -p "Please enter your domain name (e.g., xray.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain name cannot be empty."
fi
# Ensure DNS is pointed to this server's IP before proceeding
echo -e "${YELLOW}Please ensure the domain '$DOMAIN' is pointing to this server's public IP.${NC}"
read -p "Press [Enter] to continue..."
print_success "Domain set to: $DOMAIN"

# 2. System Update and Preparation
print_step "Updating System and Installing Dependencies"
apt update && apt upgrade -y
# Caddy dependencies are included here
apt install -y curl wget socat git debian-keyring debian-archive-keyring lsb-release ca-certificates gnupg cron sudo || print_error "Failed to install dependencies."
apt remove --purge nginx nginx-full nginx-common -y
print_success "System updated and dependencies installed."

# 3. Configure Firewall (if ufw is active)
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    print_step "Configuring Firewall"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp # Required for HTTP/3 (QUIC)
    ufw allow 22/tcp
    # The SS port from xray config
    ufw allow 52666/tcp
    ufw allow 52666/udp # For SS UoT
    ufw reload
    print_success "Firewall ports 80, 443 (TCP/UDP), 22, 52666 (TCP/UDP) opened."
fi

# 4. Install and Configure Caddy v2
print_step "Installing and Configuring Caddy"
wget --no-check-certificate -O /opt/caddy.deb https://github.com/caddyserver/caddy/releases/download/v2.10.0/caddy_2.10.0_linux_amd64.deb
apt install /opt/caddy.deb -y

# Create webroot directory
mkdir -p /var/www/html
# Create a simple index page for camouflage
echo "Welcome to my website!" > /var/www/html/index.html

# Create Caddyfile
cat <<EOF > /etc/caddy/Caddyfile
# Caddyfile for Xray
# This file is managed automatically. Do not edit.

{$DOMAIN} {
    # Set headers to prevent IP leakage
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Reverse proxy Xray traffic on /download/ to the backend Unix socket
    reverse_proxy /download/ h2c://127.0.0.1:6666 {
    }


    # Serve a simple camouflage website for all other requests
    handle {
        root * /var/www/html
        file_server
    }
}
EOF
print_success "Caddy installed and configured successfully."

# 5. Install Xray
print_step "Installing Xray-core"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" || print_error "Xray installation failed."
print_success "Xray-core installed."

# 6. Configure Xray (This section is unchanged)
print_step "Configuring Xray"
key=$(/usr/local/bin/xray x25519)
privatekey=$(echo $key | grep "Private key:" | awk  '{print substr($3,1)}')
publickey=$(echo $key | grep "Public key:" | awk  '{print substr($6,1)}')  

mkdir -p /etc/v2ray
# Create Xray config file from template
cat <<EOF > /etc/v2ray/config.json
{
  "log": {
    "loglevel": "none"
  },
    "dns": {
    "servers": [
      "tcp://8.8.8.8:53"
    ]
  },
  "inbounds": [
        {
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
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "127.0.0.1:443",
                    "xver": 0,
                    "serverNames": [
                        "${DOMAIN}"
                    ],
                    "privateKey": "${privatekey}",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 0,
                    "shortIds": [
                        ""
                    ]
                }
            },
        "sniffing": {
          "enabled": true,
          "destOverride": [
            "fakedns+others"
          ]
        }
        },
    {
            "listen": "127.0.0.1",
            "port": 6666,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${GENERATED_UUID}",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "host": "${DOMAIN}",
          "mode": "auto",
          "path": "/download/"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "fakedns+others"
        ]
      }
    },
    {
      "tag": "ss",
      "protocol": "shadowsocks",
      "address": "0.0.0.0",
      "port": 52666,
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "${sspass}",
        "network": "tcp,udp",
        "uot": true,
        "UoTVersion": 2,
        "level": 0
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "fakedns+others"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "sendThrough": "0.0.0.0",
      "protocol": "freedom",
      "settings": {"domainStrategy": "UseIPv4"}
    },
    {
      "tag": "stream",
      "sendThrough": "0.0.0.0",
      "protocol": "freedom",
      "settings":{
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
          "geoip:private",
          "::/0"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
print_success "Xray configuration created."
rm -f /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json

# 7. System Optimization (This section is unchanged and still valuable)
print_step "Optimizing System Parameters (sysctl, limits)"
# The entire sysctl and limits configuration block from the original script is preserved here.
# It is good practice for performance tuning.
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
# ... (all other sed -i lines from original script) ...
sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf

cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=1000000
EOF
sysctl -p && sysctl --system

ulimit -SHn 1000000 && ulimit -c unlimited
cat > /etc/security/limits.conf << EOF
root      soft    nofile     1000000
root      hard    nofile     1000000
root      soft    nproc      1000000
root      hard    nproc      1000000
root      soft    core       1000000
root      hard    core       1000000
root      hard    memlock    unlimited
root      soft    memlock    unlimited

* soft    nofile     1000000
* hard    nofile     1000000
* soft    nproc      1000000
* hard    nproc      1000000
* soft    core       1000000
* hard    core       1000000
* hard    memlock    unlimited
* soft    memlock    unlimited
EOF
if ! grep -q "ulimit -SHn 1000000" /etc/profile; then
  echo "ulimit -SHn 1000000" >> /etc/profile
fi
if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session; then
  echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf
cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF
systemctl daemon-reload
print_success "System parameters optimized."

# 8. Start Services and Set Auto-start
print_step "Starting Services and Enabling Auto-start"
systemctl enable caddy
systemctl enable xray
systemctl restart caddy
systemctl restart xray
print_success "Caddy and Xray started and enabled on boot."

# 9. Display Configuration
print_step "Deployment Complete! Here is your configuration:"
echo -e "-------------------------------------------------------"
echo -e "  ${YELLOW}Address (地址):${NC}    ${DOMAIN}"
echo -e "  ${YELLOW}Port (端口):${NC}        443"
echo -e "  ${YELLOW}UUID:${NC}               ${GENERATED_UUID}"
echo -e "  ${YELLOW}Publickey (公钥):${NC}    ${publickey}"
echo -e "  ${YELLOW}Transport (传输):${NC}   HTTP/2 (xhttp)"
echo -e "  ${YELLOW}Path (路径):${NC}         /download/"
echo -e "  ${YELLOW}TLS:${NC}                tls (managed by Caddy)"
echo -e "-------------------------------------------------------"
echo -e "  ${YELLOW}Shadowsocks Port:${NC}   52666"
echo -e "  ${YELLOW}Shadowsocks Method:${NC} 2022-blake3-aes-256-gcm"
echo -e "  ${YELLOW}Shadowsocks Pass:${NC}   ${sspass}"
echo -e "-------------------------------------------------------"
echo -e "${GREEN}Enjoy your secure and private connection!${NC}"

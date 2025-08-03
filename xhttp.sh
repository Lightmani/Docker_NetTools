#!/bin/bash

#===============================================================================================
#   Xray & Nginx One-Click Deployment Script for Debian 12
#
#   Author: Gemini
#   Version: 1.0
#   Description: This script automates the setup of Xray with VLESS+H2+TLS,
#                using Nginx as a reverse proxy and acme.sh for SSL certificates.
#
#===============================================================================================

#--- [Color Codes] ---
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

#--- [Script Configuration] ---
# Auto-generate a UUID
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
print_success "Domain set to: $DOMAIN"

# 2. System Update and Preparation
print_step "Updating System and Installing Dependencies"
apt update && apt upgrade -y
apt install -y curl wget socat git debian-archive-keyring lsb-release ca-certificates gnupg2 cron || print_error "Failed to install dependencies."
print_success "System updated and dependencies installed."

apt-get remove --purge nginx nginx-full nginx-common -y


# 4. Configure Firewall (if ufw is active)
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    print_step "Configuring Firewall"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 22/tcp
    ufw reload
    print_success "Firewall ports 80 and 443 opened."
fi

# 5. Certificate Application using acme.sh
print_step "Applying for SSL Certificate with acme.sh"
# Install acme.sh
curl https://get.acme.sh | sh
source ~/.bashrc
# Register account (replace with your email if you want notifications)
~/.acme.sh/acme.sh --register-account -m myemail@example.com
# Create webroot directory
mkdir -p /var/www/html
# Issue certificate
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256 || print_error "Certificate application failed."

# 3. Install Latest Nginx Mainline
print_step "Installing Latest Nginx (Mainline with QUIC/H2/TLS1.3 support)"
# Add official Nginx repository
curl -sS https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian/ $(lsb_release -cs) nginx" \
    | tee /etc/apt/sources.list.d/nginx.list

# Install Nginx
apt update
apt install -y nginx || print_error "Failed to install Nginx."
# Verify installation
nginx -v
print_success "Nginx installed successfully."

# Install certificate to a standard location
CERT_PATH="/etc/nginx/ssl/$DOMAIN.crt"
KEY_PATH="/etc/nginx/ssl/$DOMAIN.key"
mkdir -p /etc/nginx/ssl
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --key-file       "$KEY_PATH" \
    --fullchain-file "$CERT_PATH" \
    --reloadcmd      "systemctl restart nginx" || print_error "Failed to install certificate."
print_success "Certificate applied and installed successfully."

# 6. Configure Nginx
print_step "Configuring Nginx as a Reverse Proxy"
# Create Nginx config file from template
cat <<EOF > /etc/nginx/conf.d/xray.conf
server {
    listen 80;
    server_name ${DOMAIN};
    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen [::]:443 ssl ipv6only=off reuseport;
    listen [::]:443 quic reuseport ipv6only=off;

    server_name ${DOMAIN};
  http2 on;
    # SSL Configuration
    ssl_certificate ${CERT_PATH};
    ssl_certificate_key ${KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    client_header_timeout 5m;
    keepalive_timeout 5m;
    
    # Basic camouflage site
    location / {
        root /var/www/html;
        index index.html;
        # You can put a simple static website here for camouflage
    }

    # Proxy configuration for Xray
	location /download/ {
        client_max_body_size 0;
	grpc_set_header Host \$host;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        client_body_timeout 5m;
        grpc_read_timeout 315;
        grpc_send_timeout 5m;
        grpc_pass unix:/dev/shm/xrxh.socket;
    }
}
EOF
# Create a simple index page for camouflage
echo "Welcome to my website!" > /var/www/html/index.html
# Test Nginx configuration
nginx -t || print_error "Nginx configuration test failed."
print_success "Nginx configuration created."

# 7. Install Xray
print_step "Installing Xray-core"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" || print_error "Xray installation failed."
print_success "Xray-core installed."

# 8. Configure Xray
print_step "Configuring Xray"
mkdir /etc/v2ray
chmod 755 /etc/v2ray/*
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
      "listen": "/dev/shm/xrxh.socket,0666",
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
          "mode": "packet-up",
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
"network": "tcp",
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
"domainStrategy": "UseIPv4",
"servers":[{
"address":"1.1.1.1",
"port":52666,
"method":"2022-blake3-aes-256-gcm",
"password":"1",
"email": "love@xray.com"
}]
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
"geostie:category-ai-!cn"
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
print_success "Xray configuration created."
rm /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json

# 9. Start Services and Set Auto-start
print_step "Starting Services and Enabling Auto-start"
systemctl enable nginx
systemctl enable xray
systemctl restart nginx
systemctl restart xray
print_success "Nginx and Xray started and enabled on boot."

# 10. Cleanup
print_step "Cleaning Up"
apt autoremove -y > /dev/null 2>&1
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
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
EOF
sysctl -p && sysctl --system

echo "1000000" > /proc/sys/fs/file-max
sed -i '/fs.file-max/d' /etc/sysctl.conf
cat >> '/etc/sysctl.conf' << EOF
fs.file-max=1000000
EOF

ulimit -SHn 1000000 && ulimit -c unlimited
echo "root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     1000000
root     hard   nproc     1000000
root     soft   core      1000000
root     hard   core      1000000
root     hard   memlock   unlimited
root     soft   memlock   unlimited

*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc     1000000
*     hard   nproc     1000000
*     soft   core      1000000
*     hard   core      1000000
*     hard   memlock   unlimited
*     soft   memlock   unlimited
">/etc/security/limits.conf
if grep -q "ulimit" /etc/profile; then
  :
else
  sed -i '/ulimit -SHn/d' /etc/profile
  echo "ulimit -SHn 1000000" >>/etc/profile
fi
if grep -q "pam_limits.so" /etc/pam.d/common-session; then
  :
else
  sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
  echo "session required pam_limits.so" >>/etc/pam.d/common-session
fi

sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
#DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
#DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

systemctl daemon-reload
print_success "Unnecessary packages removed."

# 11. Display Configuration
print_step "Deployment Complete! Here is your configuration:"
echo -e "-------------------------------------------------------"
echo -e "  ${YELLOW}Address (地址):${NC}    ${DOMAIN}"
echo -e "  ${YELLOW}Port (端口):${NC}        443"
echo -e "  ${YELLOW}UUID:${NC}               ${GENERATED_UUID}"
echo -e "  ${YELLOW}Protocol (协议):${NC}    vless"
echo -e "  ${YELLOW}Transport (传输):${NC}   XHTTP"
echo -e "  ${YELLOW}SS (密码):${NC}        ${sspass}"
echo -e "  ${YELLOW}TLS:${NC}                tls"
echo -e "-------------------------------------------------------"
echo -e "${GREEN}Enjoy your secure and private connection!${NC}"

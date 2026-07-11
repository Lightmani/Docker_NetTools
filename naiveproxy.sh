#!/usr/bin/env bash
#===============================================================================
#  一键部署 NaiveProxy(Caddy+klzgrad forwardproxy) + Xray SS2022
#  适用: Debian 12 / 13 及更高版本 (systemd)
#
#  架构说明:
#    - NaiveProxy 服务端 == 打了 klzgrad padding 补丁的 Caddy 本体
#      本脚本用 xcaddy 现场编译: Caddy 主体=官方最新, forwardproxy=klzgrad @naive 源码
#    - Xray 仅配置 Shadowsocks-2022 (2022-blake3-aes-256-gcm), 固定端口 52666
#
#  前提(必读):
#    1. 你必须拥有一个已解析到本机公网IP的域名 (A/AAAA 记录)
#    2. 服务器 80 与 443 端口必须可从公网访问 (Caddy 申请证书用)
#    3. 云厂商安全组需放行 TCP/UDP 80,443,52666
#===============================================================================
set -euo pipefail

#--------------------------- 基础检查 ------------------------------------------
[[ $EUID -eq 0 ]] || { echo "请以 root 运行 (sudo -i)"; exit 1; }

if ! grep -qiE 'debian' /etc/os-release; then
    echo "警告: 本脚本仅针对 Debian 12/13+, 其他系统未测试。"
    read -rp "仍要继续? (y/N): " _c; [[ "${_c,,}" == y ]] || exit 1
fi

ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64|amd64) GOARCH=amd64 ;;
    aarch64|arm64) GOARCH=arm64 ;;
    *) echo "不支持的架构: $ARCH_RAW"; exit 1 ;;
esac

echo ">>> 更新系统并安装依赖 ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget tar git ca-certificates openssl dnsutils jq libcap2-bin >/dev/null

#--------------------------- 交互: 域名与邮箱 ----------------------------------
echo
echo "================= 配置输入 ================="
read -rp "请输入你的域名 (已解析到本机, 如 proxy.example.com): " DOMAIN
[[ -n "$DOMAIN" ]] || { echo "域名不能为空"; exit 1; }
read -rp "请输入用于 Let's Encrypt 的邮箱: " EMAIL
[[ -n "$EMAIL" ]] || { echo "邮箱不能为空"; exit 1; }

# DNS 解析预检: 比对域名解析 IP 与本机公网 IP
echo ">>> 检查域名解析 ..."
PUBIP=$(curl -fsSL4 https://api.ipify.org || curl -fsSL https://ifconfig.me || echo "")
RESOLVED=$(dig +short A "$DOMAIN" | tail -n1 || true)
if [[ -n "$PUBIP" && -n "$RESOLVED" && "$PUBIP" != "$RESOLVED" ]]; then
    echo "!! 警告: 域名解析到 [$RESOLVED], 本机公网 IP 为 [$PUBIP], 不一致。"
    echo "   若解析尚未生效或使用了 CDN/AAAA, Caddy 可能无法签发证书。"
    read -rp "仍要继续? (y/N): " _c; [[ "${_c,,}" == y ]] || exit 1
fi

# 随机生成 NaiveProxy 认证凭据
NAIVE_USER="user_$(openssl rand -hex 4)"
NAIVE_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 24)

# 生成 SS2022 密钥 (2022-blake3-aes-256-gcm 需 32 字节)
SS_METHOD="2022-blake3-aes-256-gcm"
SS_PORT=52666
SS_PASS=$(openssl rand -base64 32)

#--------------------------- 小内存临时 swap ------------------------------------
MEM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
SWAP_KB=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
CREATED_SWAP=0
if [[ "$MEM_KB" -lt 1048576 && "$SWAP_KB" -lt 262144 ]]; then
    echo ">>> 内存偏小且无 swap, 创建 1G 临时 swap 以防编译 OOM ..."
    if fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024; then
        chmod 600 /swapfile; mkswap /swapfile >/dev/null; swapon /swapfile
        CREATED_SWAP=1
    fi
fi

#--------------------------- 安装最新版 Go -------------------------------------
# 注意: 不用 apt 的 golang(通常过旧), 直接取 go.dev 最新稳定版, 否则新版 Caddy 编译失败
echo ">>> 安装最新版 Go 工具链 ..."
GO_LATEST=$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)
GO_TARBALL="${GO_LATEST}.linux-${GOARCH}.tar.gz"
wget -qO "/tmp/${GO_TARBALL}" "https://go.dev/dl/${GO_TARBALL}"
rm -rf /usr/local/go
tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
export PATH=$PATH:/usr/local/go/bin:/root/go/bin
export GOPATH=/root/go
echo ">>> Go 版本: $(/usr/local/go/bin/go version)"

#--------------------------- 用 xcaddy 编译 Caddy+forwardproxy(klzgrad@naive) --
echo ">>> 安装 xcaddy 并编译 Caddy (官方最新) + klzgrad forwardproxy@naive ..."
/usr/local/go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# 核心: Caddy 主体默认拉官方最新; forwardproxy 用 klzgrad @naive 源码(含 padding 协议)
/root/go/bin/xcaddy build \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive \
    --output /usr/local/bin/caddy

chmod +x /usr/local/bin/caddy
# 赋予绑定低端口能力(备用, systemd 已给 AmbientCapabilities)
setcap cap_net_bind_service=+ep /usr/local/bin/caddy || true
echo ">>> Caddy 版本: $(/usr/local/bin/caddy version)"

#--------------------------- 创建 caddy 用户与目录 -----------------------------
id caddy &>/dev/null || useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy
mkdir -p /etc/caddy /var/lib/caddy /var/www/html
chown -R caddy:caddy /var/lib/caddy

# 一个朴素的伪装首页(避免访问根路径时空白, 增加真实性)
cat > /var/www/html/index.html <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Welcome</title></head><body><h1>It works!</h1></body></html>
HTML
chown -R caddy:caddy /var/www/html

#--------------------------- 写 Caddyfile --------------------------------------
cat > /etc/caddy/Caddyfile <<EOF
{
    order forward_proxy before file_server
    log {
        exclude http.log.error
    }
}

:443, ${DOMAIN} {
    tls ${EMAIL}
    encode
    forward_proxy {
        basic_auth ${NAIVE_USER} ${NAIVE_PASS}
        hide_ip
        hide_via
        probe_resistance
    }
    file_server {
        root /var/www/html
    }
}
EOF

# 校验配置
/usr/local/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

#--------------------------- Caddy systemd 服务 --------------------------------
cat > /etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy (NaiveProxy forward_proxy)
After=network-online.target
Wants=network-online.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile --adapter caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now caddy
sleep 3
systemctl --no-pager -l status caddy | head -n 12 || true

#--------------------------- 安装 Xray (BETA) ----------------------------------
echo ">>> 安装 Xray-core (beta/预发布版) ..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta

#--------------------------- 写 Xray 配置(仅 SS2022) ---------------------------
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
   "dns": {
    "servers": [
    "tcp+local://8.8.8.8:53",
     {
        "address": "8.8.8.8",
        "port": 53,
        "domains": [
"geosite:netflix"
        ]
      }

    ]
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${SS_PORT},
      "protocol": "shadowsocks",
      "settings": {
        "method": "${SS_METHOD}",
        "password": "${SS_PASS}",
        "network": "tcp,udp"
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
            "protocol": "freedom",
         "settings":{
         "domainStrategy": "UseIPv4"
        }},
{
"tag": "stream",
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
}
    ],
"routing": {
    "rules": [
        {
"type": "field",
"domain": [
"geosite:netflix",
"geostie:category-ai-!cn"
],
"outboundTag": "stream"
}
    ],
    "strategy": "rules"
  }
}
EOF

# 校验并重启 Xray
if xray -test -config /usr/local/etc/xray/config.json; then
    systemctl restart xray
    systemctl enable xray >/dev/null 2>&1 || true
else
    echo "!! Xray 配置校验失败, 请检查。"
fi
sleep 2
systemctl --no-pager -l status xray | head -n 10 || true

#--------------------------- 清理临时 swap(可选保留) ----------------------------
# 如需回收编译期临时 swap, 取消下面注释:
# if [[ "$CREATED_SWAP" -eq 1 ]]; then swapoff /swapfile && rm -f /swapfile; fi

#--------------------------- 输出凭据 ------------------------------------------
SS_LINK_USERINFO=$(printf '%s:%s' "$SS_METHOD" "$SS_PASS" | base64 -w0)
SS_LINK="ss://${SS_LINK_USERINFO}@${PUBIP:-$DOMAIN}:${SS_PORT}#SS2022-${DOMAIN}"

CRED_FILE=/etc/naive-xray-credentials.txt
cat > "$CRED_FILE" <<EOF
================ NaiveProxy (Caddy forward_proxy) ================
域名        : ${DOMAIN}
监听端口    : 443 (TLS)
用户名      : ${NAIVE_USER}
密码        : ${NAIVE_PASS}

naive 客户端 config.json:
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://${NAIVE_USER}:${NAIVE_PASS}@${DOMAIN}"
}

================ Xray Shadowsocks-2022 ================
地址        : ${PUBIP:-$DOMAIN}
端口        : ${SS_PORT}
加密方式    : ${SS_METHOD}
密码(密钥)  : ${SS_PASS}
分享链接    : ${SS_LINK}
================================================================
EOF
chmod 600 "$CRED_FILE"

echo
echo "########################################################"
echo "#  部署完成!  凭据已保存至: ${CRED_FILE}"
echo "########################################################"
cat "$CRED_FILE"
echo
echo "提示:"
echo "  - 若 Caddy 未能签发证书, 请确认域名解析生效且 80/443 未被占用/被墙。"
echo "  - 云厂商安全组请放行 TCP 80,443 与 TCP/UDP ${SS_PORT}。"
echo "  - 查看日志: journalctl -u caddy -e   /   journalctl -u xray -e"

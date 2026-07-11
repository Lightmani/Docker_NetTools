#!/usr/bin/env bash
#===============================================================================
#  一键部署 NaiveProxy(Caddy+klzgrad@naive 现编译) + Xray SS2022
#  【极小磁盘机器专用版】—— 全程受控编译目录 + 绕开 tmpfs + 即焚工具链
#  适用: Debian 12/13+, 根盘紧张(清理后需 >=2.5G 可用)
#===============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "请以 root 运行"; exit 1; }

ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64|amd64) GOARCH=amd64 ;;
    aarch64|arm64) GOARCH=arm64 ;;
    *) echo "不支持的架构: $ARCH_RAW"; exit 1 ;;
esac

#===============================================================================
#  第 0 步: 深度清理上次失败残骸 —— 这是本机能编译成功的前提
#===============================================================================
echo ">>> 清理上次编译残骸, 回收根盘空间 ..."
rm -rf /root/go                      # 上次 GOPATH(1.1G, 可能已损坏, 必删)
rm -rf /root/.cache/go-build         # 上次 GOCACHE(~247M)
rm -rf /usr/local/go                 # 上次 Go 工具链(将重装干净的)
rm -f  /tmp/go*.tar.gz               # Go 安装包残留(64M)
rm -rf /root/build_workspace         # 本脚本工作区(若存在)
apt-get clean
rm -rf /var/lib/apt/lists/*          # apt 索引(156M, 稍后 update 会重建)
sync

echo ">>> 清理后根盘状况:"
df -h /
AVAIL_KB=$(df -k / | awk 'NR==2{print $4}')
if [[ "$AVAIL_KB" -lt 2359296 ]]; then   # 2.25G
    echo "!! 警告: 清理后可用空间仍 < 2.25G, 现编译风险很高。"
    read -rp "仍要继续? (y/N): " _c; [[ "${_c,,}" == y ]] || exit 1
fi

#===============================================================================
#  第 1 步: 依赖 + 交互输入
#===============================================================================
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget tar git ca-certificates openssl dnsutils libcap2-bin >/dev/null

echo
echo "================= 配置输入 ================="
read -rp "请输入你的域名 (已解析到本机): " DOMAIN
[[ -n "$DOMAIN" ]] || { echo "域名不能为空"; exit 1; }
read -rp "请输入 Let's Encrypt 邮箱: " EMAIL
[[ -n "$EMAIL" ]] || { echo "邮箱不能为空"; exit 1; }

PUBIP=$(curl -fsSL4 https://api.ipify.org || curl -fsSL https://ifconfig.me || echo "")
RESOLVED=$(dig +short A "$DOMAIN" | tail -n1 || true)
if [[ -n "$PUBIP" && -n "$RESOLVED" && "$PUBIP" != "$RESOLVED" ]]; then
    echo "!! 警告: 域名解析[$RESOLVED] 与本机公网IP[$PUBIP] 不一致。"
    read -rp "仍要继续? (y/N): " _c; [[ "${_c,,}" == y ]] || exit 1
fi

NAIVE_USER="user_$(openssl rand -hex 4)"
NAIVE_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 24)
SS_METHOD="2022-blake3-aes-256-gcm"
SS_PORT=52666
SS_PASS=$(openssl rand -base64 32)

#===============================================================================
#  第 2 步: 临时 swap(内存极小, 编译防 OOM)
#===============================================================================
MEM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
SWAP_KB=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
CREATED_SWAP=0
# swap 文件放根盘, 编译后回收; 内存<800M 且 swap 不足时创建
if [[ "$MEM_KB" -lt 819200 && "$SWAP_KB" -lt 524288 ]]; then
    echo ">>> 内存极小, 创建 1G 临时 swap 防 OOM ..."
    if fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024; then
        chmod 600 /swapfile; mkswap /swapfile >/dev/null; swapon /swapfile; CREATED_SWAP=1
    fi
fi

#===============================================================================
#  第 3 步(修复版): 受控编译环境
#  修复要点:
#    - 只设 Go 专用 GOTMPDIR, 不污染全局 TMPDIR(避免影响 Xray 等后续程序)
#    - 用 trap EXIT 注册 cleanup: 无论成功/失败/中断都自动即焚+复原环境
#===============================================================================
WORK=/root/build_workspace
mkdir -p "$WORK"/{gotmp,gocache,gomod,gopath}
# ---- 关键修复: cleanup 函数 + trap, 保证目录与环境变量同生共死 ----
cleanup() {
    echo ">>> [cleanup] 回收编译工具链/缓存并复原环境 ..."
    rm -rf /usr/local/go "$WORK"
    # !! 核心修复: 删目录的同时, 撤销所有指向该目录的环境变量
    unset GOROOT GOPATH GOCACHE GOMODCACHE GOTMPDIR GOFLAGS GOPROXY
    if [[ "${CREATED_SWAP:-0}" -eq 1 ]]; then
        swapoff /swapfile 2>/dev/null && rm -f /swapfile
    fi
}
trap cleanup EXIT      # 脚本无论如何退出(正常/报错/Ctrl-C)都会执行 cleanup
export GOROOT=/usr/local/go
export GOPATH="$WORK/gopath"
export GOCACHE="$WORK/gocache"
export GOMODCACHE="$WORK/gomod"
export GOTMPDIR="$WORK/gotmp"     # 只用 Go 专用临时目录, 绕开 233M /tmp
# 注意: 不再 export TMPDIR ! 这就是上次污染 Xray mktemp 的元凶。
#       Go 只认 GOTMPDIR; 系统其他程序(如 Xray)继续用默认 /tmp(20M 包够用)
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
export GOFLAGS="-ldflags=-s -ldflags=-w"
# export GOPROXY=https://goproxy.cn,direct   # 国内网络差时解除注释
echo ">>> 安装干净的 Go 工具链 ..."
GO_LATEST=$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)
GO_TARBALL="${GO_LATEST}.linux-${GOARCH}.tar.gz"
wget -qO "$WORK/${GO_TARBALL}" "https://go.dev/dl/${GO_TARBALL}"
tar -C /usr/local -xzf "$WORK/${GO_TARBALL}"
rm -f "$WORK/${GO_TARBALL}"
echo ">>> Go: $(go version)"
echo ">>> 编译 xcaddy ..."
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
echo ">>> 编译 Caddy(官方最新) + klzgrad forwardproxy@naive ..."
xcaddy build \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive \
    --output /usr/local/bin/caddy
chmod +x /usr/local/bin/caddy
setcap cap_net_bind_service=+ep /usr/local/bin/caddy || true
echo ">>> Caddy: $(/usr/local/bin/caddy version)"
#===============================================================================
#  第 4 步(修复版): 不再手动 rm/即焚!
#  即焚已交给 trap EXIT 里的 cleanup 自动完成 —— 删除原来这里的 rm 逻辑。
#  好处: 即使后面 Xray 步骤或任何命令报错退出, cleanup 也会被触发,
#        不会留下 1.1G 编译垃圾, 也不会留下污染环境的变量。
#===============================================================================
echo ">>> 编译完成, 后续清理将在脚本退出时由 trap 自动执行。"
df -h /

#===============================================================================
#  第 5 步: Caddy 用户/目录/配置/服务
#===============================================================================
id caddy &>/dev/null || useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy
mkdir -p /etc/caddy /var/lib/caddy /var/www/html
chown -R caddy:caddy /var/lib/caddy
cat > /var/www/html/index.html <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Welcome</title></head><body><h1>It works!</h1></body></html>
HTML
chown -R caddy:caddy /var/www/html

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
/usr/local/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

cat > /etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy (NaiveProxy forward_proxy)
After=network-online.target
Wants=network-online.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
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

#===============================================================================
#  第 6 步: Xray(beta) + 仅 SS2022 配置
#===============================================================================
echo ">>> 安装 Xray-core (beta) ..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta

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
if xray -test -config /usr/local/etc/xray/config.json; then
    systemctl restart xray; systemctl enable xray >/dev/null 2>&1 || true
else
    echo "!! Xray 配置校验失败"
fi
sleep 2
systemctl --no-pager -l status xray | head -n 10 || true

#===============================================================================
#  第 7 步: 输出凭据
#===============================================================================
SS_LINK_USERINFO=$(printf '%s:%s' "$SS_METHOD" "$SS_PASS" | base64 -w0)
SS_LINK="ss://${SS_LINK_USERINFO}@${PUBIP:-$DOMAIN}:${SS_PORT}#SS2022-${DOMAIN}"
CRED_FILE=/etc/naive-xray-credentials.txt
cat > "$CRED_FILE" <<EOF
================ NaiveProxy (Caddy forward_proxy) ================
域名        : ${DOMAIN}
端口        : 443 (TLS)
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
echo "########## 部署完成! 凭据已存至 ${CRED_FILE} ##########"
cat "$CRED_FILE"
echo
echo "查看日志: journalctl -u caddy -e  /  journalctl -u xray -e"

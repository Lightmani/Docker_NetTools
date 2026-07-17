#!/usr/bin/env bash
set -euo pipefail

# ========= 配置区 =========
CF_API_TOKEN="你的_API_Token"          # Cloudflare API Token（仅需 Zone.DNS 编辑权限）
ZONE_ID="你的_Zone_ID"                  # 域名对应的 Zone ID
RECORD_NAME="ddns.example.com"          # 要更新的完整域名
PROXIED=false                           # 是否走 Cloudflare 代理(橙云), DDNS 通常 false
# =========================

API="https://api.cloudflare.com/client/v4"
AUTH="Authorization: Bearer ${CF_API_TOKEN}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: 未安装 jq，请先 apt install jq / yum install jq"; exit 1; }

# 1. 获取当前公网 IPv4（外部回显，兼容 NAT VPS）
CURRENT_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.co)
[ -z "$CURRENT_IP" ] && { echo "ERROR: 获取公网 IP 失败"; exit 1; }

# 2. 查询 Cloudflare 现有记录
RESP=$(curl -s -H "$AUTH" -H "Content-Type: application/json" \
  "${API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}")

# 先确认 API 调用本身成功
if [ "$(echo "$RESP" | jq -r '.success')" != "true" ]; then
  echo "ERROR: 查询记录失败，Cloudflare 返回："
  echo "$RESP" | jq '.errors'
  exit 1
fi

RECORD_ID=$(echo "$RESP" | jq -r '.result[0].id // empty')
OLD_IP=$(echo "$RESP" | jq -r '.result[0].content // empty')

[ -z "$RECORD_ID" ] && { echo "ERROR: 找不到记录 $RECORD_NAME，请先在 Cloudflare 手动创建一条 A 记录"; exit 1; }

# 3. IP 未变则跳过
if [ "$CURRENT_IP" = "$OLD_IP" ]; then
  echo "IP 未变化 ($CURRENT_IP)，无需更新"
  exit 0
fi

# 4. IP 变了，执行更新
UPDATE=$(curl -s -X PATCH -H "$AUTH" -H "Content-Type: application/json" \
  "${API}/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  --data "$(jq -n \
    --arg ip "$CURRENT_IP" \
    --arg name "$RECORD_NAME" \
    --argjson proxied "$PROXIED" \
    '{type:"A", name:$name, content:$ip, proxied:$proxied}')")

if [ "$(echo "$UPDATE" | jq -r '.success')" = "true" ]; then
  echo "更新成功: $OLD_IP -> $CURRENT_IP"
else
  echo "ERROR: 更新失败，Cloudflare 返回："
  echo "$UPDATE" | jq '.errors'
  exit 1
fi

read -p " 出口IP1:" ipa
read -p " 出口IP2:" ipb

apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron -y

netsh interface tcp set global timestamps=enabled


#bbr
cat > /etc/sysctl.conf <<EOF
fs.file-max = 1000000

net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_syn_retries=1
net.ipv4.tcp_rmem=4096 65536 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq_pie
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl -p && sysctl --system

sed -i '/net.ipv4.conf.all.route_localnet/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.forwarding/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.default.forwarding/d' /etc/sysctl.conf
cat >> '/etc/sysctl.conf' << EOF
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
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




echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools









#V2ray
mkdir /etc/v2ray
chmod 755 /etc/v2ray/*

chmod 755 /etc/v2ray/*


bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 1.8.4



rm /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json
service xray restart
systemctl enable xray
apt autoremove -y


pass0=$(cat /proc/sys/kernel/random/uuid)
pass=$pass0

cd /etc/v2ray/
cat>config.json<<EOF
{
    "log": {
        "loglevel": "none"
    },
  "dns": {
    "servers": [
    "1.1.1.1",
   "8.8.8.8"
    ]
  },
    "inbounds": [
    {
 "tag": "in1",
 "protocol": "shadowsocks",
 "address": "0.0.0.0",
            "port": 50001,
"settings": {

            "method": "chacha20-ietf-poly1305",
            "password": "$pass",
"network": "tcp,udp",
            "level": 0

}
},
    {
 "tag": "in2",
 "protocol": "shadowsocks",
 "address": "0.0.0.0",
            "port": 50002,
"settings": {

            "method": "chacha20-ietf-poly1305",
            "password": "$pass",
"network": "tcp,udp",
            "level": 0

}
}


    ],
  "outbounds": [
{
"tag": "out1",
"sendThrough": "$ipa",
"protocol": "freedom",
"settings":{
"domainStrategy": "UseIPv4"
}
},
   {
"tag": "out2",
"sendThrough": "$ipb",
"protocol": "freedom",
"settings":{
"domainStrategy": "UseIPv4"
}
}
    ],
"routing": {
    "rules": [
        {
          "inboundTag": ["in1"],
"type": "field",
"outboundTag": "out1"
},
        {
          "inboundTag": ["in2"],
"type": "field",
"outboundTag": "out2"
}

    ],
    "strategy": "rules"
  }
}
EOF

echo -e "${Red} 用户id（UUID）：${Font} ${pass}"

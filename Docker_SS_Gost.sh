#初始环境


apt update 
apt upgrade -y
apt install vim ufw curl wget unzip rng-tools -y
#bbr

sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

pass=$(cat /proc/sys/kernel/random/uuid)


apt install ufw -y
ufw default allow
ufw default deny
ufw allow 8443
ufw allow 443
ufw allow 80
ufw allow 22
ufw allow 55555
ufw enable


#Docker
wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

#Shadowsocks
mkdir /etc/shadowsocks-libev
cd /etc/shadowsocks-libev
cat>config.json<<EOF
{
"server":"0.0.0.0",
"server_port":55555,
"password":"$pass",
"timeout":300,
"method":"aes-128-gcm",
"fast_open":true,
"nameserver":"1.0.0.1",
"mode":"tcp_and_udp",
"plugin":"",
"plugin_opts":""
}
EOF
docker run -d --name ss-libev --restart always --net host -v /etc/shadowsocks-libev:/etc/shadowsocks-libev teddysun/shadowsocks-libev

#gost
docker pull ginuerzh/gost
mkdir /etc/gost
cd /etc/gost
cat>config.json<<EOF
{
    "Debug": false,
    "Retries": 2,
    "ServeNodes": [
        "relay+mws://:80/127.0.0.1:55555"
    ]
}
EOF
docker run -d --net host --restart always --name gost -v /etc/gost:/etc/gost ginuerzh/gost -C /etc/gost/config.json



echo $pass

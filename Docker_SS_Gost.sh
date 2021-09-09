#初始环境

env(){

apt update 
apt upgrade -y
apt install vim ufw curl wget unzip rng-tools -y
#bbr

sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = cake" >> /etc/sysctl.conf
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
systemctl enable ufw
systemctl start ufw

#Docker
wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

}

ss(){
#Shadowsocks
read -p " 请输入你的端口:" port
read -p " 请输入你的DNS:" dns
read -p " 请输入你的Docker's Name:" name
pass=$(cat /proc/sys/kernel/random/uuid)

mkdir /etc/ss-$name
cd /etc/ss-$name
cat>config.json<<EOF
{
"server":"0.0.0.0",
"server_port":$port,
"password":"$pass",
"timeout":300,
"method":"chacha20-ietf-poly1305",
"fast_open":true,
"nameserver":"$dns",
"mode":"tcp_and_udp",
"plugin":"",
"plugin_opts":""
}
EOF
docker run -d --name $name --restart always --net host -v /etc/ss-$name:/etc/shadowsocks-libev teddysun/shadowsocks-libev

ufw allow $port
firewall-cmd --permanent --zone=public --add-port=$port/tcp
firewall-cmd --permanent --zone=public --add-port=$port/udp
firewall-cmd --reload

clear
echo 您的SS端口是$port
echo 您的SS密码是$pass
}

gost(){
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
}


echo -e "1.Environment"
echo -e "2.Add SS"
echo -e "3.Add Gost"
echo -e "4.ALL"
read -p "Press:" menu_Num
case "$menu_Num" in
	1)
	env
	;;
	2)
	ss
	;;
	3)
	gost
	;;
	4)
	env
    ss
    gost
	;;
	*)
	echo "Enter Right[1-5]:"
	;;
esac


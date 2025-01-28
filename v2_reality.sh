web(){
read -p " 请输入你的网址:" yoursite
}

#初始环境
environment(){
apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron sudo gnupg2 -y
echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools
apt install resolvconf -y
systemctl start resolvconf.service
systemctl enable resolvconf.service
cat>/etc/resolvconf/resolv.conf.d/head<<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
resolvconf -u
mkdir -p /etc/wireguard/
apt install wireguard -y
}

modify_port_UUID(){

UUID=$(cat /proc/sys/kernel/random/uuid)
sspass=$(openssl rand -base64 32)
key=$(/usr/local/bin/xray x25519)
privatekey=$(echo $key | grep "Private key:" | awk  '{print substr($3,1)}')
publickey=$(echo $key | grep "Public key:" | awk  '{print substr($6,1)}')  

sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json

sed -i "/\"password\"/c \\\t  \"password\":\"${sspass}\"," /etc/v2ray/config.json

#sed -i "/\"password\"/c \\\t  \"password\":\"${sspass}\"," /etc/sing-box/config.json

sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/v2ray/config.json

sed -i "s/hfghgrwriyubvccxz/$privatekey/g" /etc/v2ray/config.json

sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/caddy/Caddyfile

}

#Firewall
firewall(){
apt install ufw -y
ufw default allow
ufw default deny
ufw allow 2096
ufw allow 443
ufw allow 80
ufw allow 22222
ufw allow 55555
systemctl enable ufw
systemctl start ufw
}


ssha(){
cd /root
mkdir .ssh/
read -p " 请输入你的KEY:" key
echo $key >> /root/.ssh/authorized_keys
echo "PasswordAuthentication no">>/etc/ssh/sshd_config
echo "PubkeyAuthentication yes">>/etc/ssh/sshd_config
echo "Port 22222">>/etc/ssh/sshd_config
service sshd restart
}


#LNMP一键
v2_nginx(){
apt remove --purge nginx nginx-full nginx-common -y
apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat 
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl sudo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

mkdir /var/www
mkdir /var/www/site
cd /srv
wget https://github.com/zhangxiang958/Tour4U/archive/dev.zip
unzip dev.zip -d /var/www/site/
#Caddyconfig
cd /etc/caddy/
rm -f Caddyfile
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/Caddy2 -cO Caddyfile



#V2ray
mkdir /etc/v2ray
chmod 755 /etc/v2ray/*
chmod 755 /etc/v2ray/*
cd /etc/v2ray
rm config.json
wget https://raw.githubusercontent.com/Lightmani/Docker_NetTools/master/config/v2_reality.json  -cO config.json
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

modify_port_UUID
systemctl enable xray
systemctl enable caddy
service caddy restart
rm /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json
service sing-box restart
service xray restart

wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

 
mkdir /etc/ss-rust
cd /etc/ss-rust
cat>config.json<<EOF
{
"server":"127.0.0.1",
"server_port":18888,
"password":"$sspass",
"timeout":300,
"method":"chacha20-ietf-poly1305",
"fast_open":true,
"nameserver":"8.8.8.8",
"mode":"tcp_and_udp",
"plugin":"v2ray-plugin",
"plugin_opts":"server;path=/speedtest/;mux=0"
}
EOF

docker run -d --name ss-rust --restart always --net host -v /etc/ss-rust:/etc/shadowsocks-rust teddysun/shadowsocks-rust



apt autoremove -y




clear
echo "*******************************************************************"
echo -e "${Red} 用户域名：${Font} ${yoursite}"
echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
echo -e "${Red} ss密码是${sspass}"
echo -e "${Red} Public Key is ：${Font} ${publickey}"
}



echo -e "1.Environment"
echo -e "2.V2Ray+Nginx"
echo -e "3.SSH"
echo -e "4.Firewall"
echo -e "5.All"
read -p "Press:" menu_Num
case "$menu_Num" in
	1)
	environment
	;;
	2)
	web
	v2_nginx
	;;
	3)
	ssha
	;;
	4)
	firewall
	;;
	5)
	web
	environment
    v2_nginx
    ;;

	*)
	echo "Enter Right[1-5]:"
	;;
esac

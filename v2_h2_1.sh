#初始环境
web(){
read -p " 请输入你直连的网址:" yoursite

}

environment(){

apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron sudo -y
echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools

#bbr
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

}



modify_port_UUID(){

    UUID=$(cat /proc/sys/kernel/random/uuid)
    path=$(openssl rand -hex 12)
    cdnspath=$(openssl rand -hex 8)


  
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json
sed -i "/\"password\"/c \\\t  \"password\":\"${UUID}\"," /etc/v2ray/config.json

sed -i "s/SeuW56Es/$path/g" /etc/v2ray/config.json
sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/v2ray/config.json
sed -i "s/dawe321gzc/$cdnspath/g" /etc/v2ray/config.json

sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/caddy/Caddyfile
sed -i "s/SeuW56Es/$path/g" /etc/caddy/Caddyfile
sed -i "s/dawe321gzc/$cdnspath/g" /etc/caddy/Caddyfile


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


caddy(){

wget --no-check-certificate -O /opt/uninstall.sh https://github.com/Lightmani/Docker_NetTools/raw/master/uninstall.sh && chmod 755 /opt/uninstall.sh && bash /opt/uninstall.sh

apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat sudo

apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
apt update -y
apt install caddy -y

mkdir /var/www
mkdir /var/www/site
cd /srv
wget https://github.com/zhangxiang958/Tour4U/archive/dev.zip
unzip dev.zip -d /var/www/site/

cd /etc/caddy/
rm -f Caddyfile
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/Caddy2 -cO Caddyfile


}

v2(){
#V2ray
service caddy stop
mkdir /etc/v2ray



cd /etc/v2ray
rm config.json
*****************************************
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/v3.config  -cO config.json
modify_port_UUID
docker pull teddysun/v2ray
docker run -d --name v2ray --restart always --net host -v /etc/v2ray:/etc/v2ray teddysun/v2ray

service caddy restart



echo "*******************************************************************"

echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
echo -e "${Red} H2传输Path ：${Font} ${path}"
echo -e "${Red} WS传输Path ：${Font} ${cdnspath}"
}

update(){
docker pull teddysun/v2ray
docker stop v2ray
docker rm v2ray
docker run -d --name v2ray --restart always --net host -v /etc/v2ray:/etc/v2ray teddysun/v2ray


}



echo -e "1.Environment"
echo -e "2.V2Ray"
echo -e "3.SSH"
echo -e "4.Firewall"
echo -e "5.All"
echo -e "6.Update"
echo -e "7.Caddy+V2"
read -p "Press:" menu_Num
case "$menu_Num" in
	1)
	environment
	;;
	2)
	v2
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
	caddy
    v2
    ;;
	6)
	update
	;;
	7)
	web
	caddy
	v2
	;;
	*)
	echo "Enter Right[1-7]:"
	;;
esac

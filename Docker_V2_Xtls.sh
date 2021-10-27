web(){
read -p " 请输入你的网址:" yoursite
}

#初始环境
environment(){
apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron -y
apt-get remove --purge nginx nginx-full nginx-common -y

#bbr
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = cake" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1
echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools

wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

}

modify_port_UUID(){

    UUID=$(cat /proc/sys/kernel/random/uuid)




    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json
sed -i "/\"password\"/c \\\t  \"password\":\"${UUID}\"," /etc/v2ray/config.json
sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/v2ray/config.json

sed -i "/server_name/c \\\t  server_name $yoursite;" /etc/nginx/sites-enabled/site.conf
sed -i "/http_host = \"\"/c \\\t  \$http_host = \"$yoursite\"" /etc/nginx/sites-enabled/site.conf
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

apt-get remove --purge nginx nginx-full nginx-common -y
apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat 
apt install -y nginx


(echo "59 23 * * * service nginx stop >> /dev/null 2>&1" ; crontab -l ) | crontab
(echo "1 1 * * * service nginx start >> /dev/null 2>&1" ; crontab -l ) | crontab




systemctl enable nginx

mkdir /var/www
mkdir /var/www/site
cd /srv
wget https://github.com/zhangxiang958/Tour4U/archive/dev.zip
unzip dev.zip -d /var/www/site/

#config
wget --no-check-certificate -O /etc/nginx/sites-enabled/site.conf https://github.com/Lightmani/Docker_NetTools/raw/master/config/site.conf




#V2ray
#V2ray
service nginx stop
mkdir /etc/v2ray

curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m jsaafsdafa321352xcz@gmail1.com
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
chmod 755 /etc/v2ray/*
cat /etc/v2ray/v2ray.crt /etc/v2ray/v2ray.key > /etc/v2ray/v2ray.pem


cd /etc/v2ray
rm config.json
*****************************************
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/V2_XTLS.config  -cO config.json
modify_port_UUID
docker pull teddysun/v2ray
docker run -d --name v2ray --restart always --net host -v /etc/v2ray:/etc/v2ray teddysun/v2ray

service nginx restart



echo "*******************************************************************"

echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"

}

update(){

docker pull teddysun/v2ray
docker stop v2ray
docker rm v2ray
docker run -d --name v2ray --restart always --net host -v /etc/v2ray:/etc/v2ray teddysun/v2ray


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
	6)
	update
	;;

	*)
	echo "Enter Right[1-5]:"
	;;
esac

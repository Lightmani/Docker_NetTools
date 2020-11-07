#初始环境
environment(){

read -p " 请输入你的网址:" yoursite


apt update 
apt upgrade -y
apt install vim ufw curl wget unzip rng-tools -y


#bbr
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1


}

modify_port_UUID(){

    UUID=$(cat /proc/sys/kernel/random/uuid)

    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json


}

#Firewall
firewall(){
apt install ufw -y
ufw default allow
ufw default deny
ufw allow 8443
ufw allow 443
ufw allow 80
ufw allow 22
ufw allow 55555
systemctl enable ufw
systemctl start ufw
}


ssha(){

echo "PasswordAuthentication no">>/etc/ssh/sshd_config
echo "PubkeyAuthentication yes">>/etc/ssh/sshd_config
echo "Port 22222">>/etc/ssh/sshd_config
service sshd restart
}


#LNMP一键
v2_nginx(){

apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat 


apt install -y nginx
systemctl enable nginx

cat >> /etc/nginx/sites-enabled/site.conf << EOF
server {  
        listen 80;
        listen [::]:80;
        root /var/www/site/; 
        index index.php index.html;
        server_name $yoursite; 

        location / {
            try_files $uri /index.php$is_args$args;
        }

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        }
}
EOF

mkdir /etc/v2ray
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc




#rng
echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools


#V2ray
wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

mkdir /etc/v2ray
cd /etc/v2ray
rm config.json
*****************************************
wget https://raw.githubusercontent.com/Lightmani/config/master/config.json  -cO config.json
modify_port_UUID
docker pull v2fly/v2fly-core
docker run -d --name v2ray --restart always --net host -v /etc/v2ray:/etc/v2ray v2fly/v2fly-core





echo "*******************************************************************"

echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
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
	v2_nginx
	;;
	3)
	ssha
	;;
	4)
	firewall
	;;
	5)
	environment
    firewall
    v2_nginx
	;;
	*)
	echo "Enter Right[1-5]:"
	;;
esac

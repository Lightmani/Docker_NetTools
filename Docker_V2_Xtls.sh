#初始环境
environment(){

read -p " 请输入你的网址:" yoursite


apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron -y
apt remove ufw

#bbr
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1


}

modify_port_UUID(){

    UUID=$(cat /proc/sys/kernel/random/uuid)
    pass=$(openssl rand -base64 8)



    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/xray/config.json
sed -i "/\"password\"/c \\\t  \"password\":\"${pass}\"," /etc/xray/config.json

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

apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat 

mkdir /etc/xray
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/xray/v2ray.crt --keypath /etc/xray/v2ray.key --ecc





apt install -y nginx

systemctl enable nginx

cat >> /etc/nginx/sites-enabled/site.conf << EOF
server {  
        listen 80;
        listen [::]:80;
        root /var/www/site/; 
        index index.php index.html;
        server_name $yoursite; 


      
}
EOF






#rng
echo "HRNGDEVICE=/dev/urandom">>/etc/default/rng-tools


#V2ray
wget -qO- get.docker.com | bash
systemctl enable docker
systemctl start docker

mkdir /etc/xray
cd /etc/xray
rm config.json
*****************************************
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/V2_XTLS.config  -cO config.json
modify_port_UUID
docker pull teddysun/xray
docker run -d --name v2ray --restart always --net host -v /etc/xray:/etc/xray teddysun/xray

service nginx restart



echo "*******************************************************************"

echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
echo -e "${Red} SS Password ：${Font} ${pass}"
}

update(){
docker pull teddysun/xray
docker stop v2ray
docker rm v2ray
docker run -d --name v2ray --restart always --net host -v /etc/xray:/etc/xray teddysun/xray


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
    v2_nginx
    ;;
	6)
	update
	;;

	*)
	echo "Enter Right[1-5]:"
	;;
esac

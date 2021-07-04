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
~/.acme.sh/acme.sh --register-account -m jsaafsdafaxcz@gmail1.com
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/xray/v2ray.crt --keypath /etc/xray/v2ray.key --ecc





apt install -y nginx

systemctl enable nginx

mkdir /var/www
mkdir /var/www/site
cd /srv
wget https://github.com/zhangxiang958/Tour4U/archive/dev.zip
unzip dev.zip -d /var/www/site/

cat >> /etc/nginx/sites-enabled/site.conf << EOF
server {  
        listen 80;
        listen [::]:80;
        root /var/www/site/Tour4U-dev/; 
        index index.php index.html;
        server_name $yoursite; 
return 301 https://$http_host$request_uri;

#安全设定
	#屏蔽请求类型
        if ($request_method  !~ ^(POST|GET)$) {
                return  444;
        }
	add_header      X-Frame-Options         DENY;
	add_header      X-XSS-Protection        "1; mode=block";
	add_header      X-Content-Type-Options  nosniff;
	# HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
	###测试前请使用较少的时间
	### https://www.nginx.com/blog/http-strict-transport-security-hsts-and-nginx/
	add_header	Strict-Transport-Security max-age=15 always;
	
	#openssl dhparam -out dhparam.pem 2048
	#openssl dhparam -out dhparam.pem 4096
	#ssl_dhparam		/home/dhparam.pem;
	#ssl_ecdh_curve		secp384r1;

	# OCSP Stapling ---
	# fetch OCSP records from URL in ssl_certificate and cache them
	#ssl_stapling		on;
	#ssl_stapling_verify	on;
	#resolver_timeout	10s;
	#resolver	8.8.8.8	valid=300s;
			#范例 resolver	2.2.2.2		valid=300s;
      
}
server {  
        listen 127.0.0.1:8989;
        listen [::]:8989;
        root /var/www/site/Tour4U-dev/; 
        index index.php index.html;
        server_name $yoursite; 


#安全设定
	#屏蔽请求类型
        if ($request_method  !~ ^(POST|GET)$) {
                return  444;
        }
	add_header      X-Frame-Options         DENY;
	add_header      X-XSS-Protection        "1; mode=block";
	add_header      X-Content-Type-Options  nosniff;
	# HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
	###测试前请使用较少的时间
	### https://www.nginx.com/blog/http-strict-transport-security-hsts-and-nginx/
	add_header	Strict-Transport-Security max-age=15 always;
	
	#openssl dhparam -out dhparam.pem 2048
	#openssl dhparam -out dhparam.pem 4096
	#ssl_dhparam		/home/dhparam.pem;
	#ssl_ecdh_curve		secp384r1;

	# OCSP Stapling ---
	# fetch OCSP records from URL in ssl_certificate and cache them
	#ssl_stapling		on;
	#ssl_stapling_verify	on;
	#resolver_timeout	10s;
	#resolver	8.8.8.8	valid=300s;
			#范例 resolver	2.2.2.2		valid=300s;
      
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

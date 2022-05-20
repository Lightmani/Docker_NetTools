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
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_rmem=4096 32768 16777216
net.ipv4.tcp_wmem=4096 32768 16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
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
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --register-account -m jsaafsdafa321352xcz@gmail1.com
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
chmod 755 /etc/v2ray/*
cat /etc/v2ray/v2ray.crt /etc/v2ray/v2ray.key > /etc/v2ray/v2ray.pem

apt install haproxy -y
rm /etc/haproxy/haproxy.cfg
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/haproxy.conf  -cO /etc/haproxy/haproxy.cfg
systemctl restart haproxy
systemctl enable haproxy

cd /etc/v2ray
rm config.json
*****************************************
wget https://github.com/Lightmani/Docker_NetTools/raw/master/config/V2_XTLS.config  -cO config.json
modify_port_UUID
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
rm /usr/local/etc/v2ray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/v2ray/config.json
service v2ray restart
systemctl enable v2ray
service nginx restart

#Update Certify
wget --no-check-certificate -O /opt/update.sh  https://github.com/Lightmani/Docker_NetTools/raw/master/update.sh
(echo "59 23 * * * bash /opt/update.sh >> /dev/null 2>&1" ; crontab -l ) | crontab

echo "*******************************************************************"

echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"

}

update(){

bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)


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

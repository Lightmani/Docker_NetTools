web(){
read -p " 请输入你的网址:" yoursite
}

#初始环境
environment(){
apt update 
apt upgrade -y
apt install vim curl wget unzip rng-tools cron -y
apt-get remove --purge nginx nginx-full nginx-common -y

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

}

modify_port_UUID(){

UUID=$(cat /proc/sys/kernel/random/uuid)
sspass=$(openssl rand -base64 32)
key=$(/usr/local/bin/xray x25519)
privatekey=$(echo $key | grep "Private key:" | awk  '{print substr($3,1)}')
publickey=$(echo $key | grep "Public key:" | awk  '{print substr($6,1)}')  
path=$(openssl rand -hex 12)
cdnspath=$(openssl rand -hex 8)

sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json
sed -i "/\"password\"/c \\\t  \"password\":\"${sspass}\"," /etc/v2ray/config.json
sed -i "s/SeuW56Es/$path/g" /etc/v2ray/config.json
sed -i "s/dawe321gzc/$cdnspath/g" /etc/v2ray/config.json

sed -i "s/dasdczxyrtgm345xa2/$yoursite/g" /etc/v2ray/config.json

sed -i "s/hfghgrwriyubvccxz/$privatekey/g" /etc/v2ray/config.json

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


#LNMP一键
v2_nginx(){

apt-get remove --purge nginx nginx-full nginx-common -y
apt install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat 

apt install -y debian-keyring debian-archive-keyring apt-transport-https sudo
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
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
wget --no-check-certificate -O /etc/v2ray/origin.key https://github.com/Lightmani/Docker_NetTools/raw/master/origin.key
wget --no-check-certificate -O /etc/v2ray/origin.pem https://github.com/Lightmani/Docker_NetTools/raw/master/origin.pem
wget --no-check-certificate -O /etc/v2ray/xbox.pem https://github.com/Lightmani/Docker_NetTools/raw/master/xbox.pem
wget --no-check-certificate -O /etc/v2ray/xbox.key https://github.com/Lightmani/Docker_NetTools/raw/master/xbox.key
cat /etc/v2ray/v2ray.crt /etc/v2ray/v2ray.key > /etc/v2ray/v2ray.pem
chmod 755 /etc/v2ray/*


cd /etc/v2ray
rm config.json
*****************************************
wget https://raw.githubusercontent.com/Lightmani/Docker_NetTools/master/config/v2_reality.json  -cO config.json
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 1.8.9

modify_port_UUID

service caddy restart
rm /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json
service xray restart
systemctl enable xray
systemctl enable caddy
apt autoremove -y




clear
echo "*******************************************************************"
echo -e "${Red} 用户域名：${Font} ${yoursite}"
echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
echo -e "${Red} ss密码是${sspass}"
echo -e "${Red} Public Key is ：${Font} ${publickey}"
echo -e "${Red} H2传输Path ：${Font} ${path}"
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

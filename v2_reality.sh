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
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
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

    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," /etc/v2ray/config.json
sed -i "/\"password\"/c \\\t  \"password\":\"${sspass}\"," /etc/v2ray/config.json


sed -i "s/hfghgrwriyubvccxz/$privatekey/g" /etc/v2ray/config.json



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

#V2ray
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
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 1.8.1

modify_port_UUID

rm /usr/local/etc/xray/config.json
ln -s /etc/v2ray/config.json /usr/local/etc/xray/config.json
service xray restart
systemctl enable xray
apt autoremove -y



wget https://github.com/EAimTY/tuic/releases/download/0.8.5/tuic-server-0.8.5-x86_64-linux-gnu

cat >>'/root/tuic.conf' <<EOF
{
    "port": 443,
    "token": [""],
    "certificate": "/etc/v2ray/v2ray.pem",
    "private_key": "/etc/v2ray/v2ray.key",

    "ip": "0.0.0.0",
    "congestion_controller": "bbr",
    "max_idle_time": 15000,
    "authentication_timeout": 1000,
    "alpn": ["h3"],
    "max_udp_relay_packet_size": 1500,
    "log_level": "off"
}
EOF

wget --no-check-certificate -O /opt/hy.sh https://raw.githubusercontent.com/HyNetwork/hysteria/master/install_server.sh
chmod +x /opt/hy.sh
bash /opt/hy.sh
rm /etc/hysteria/config.json
cat >>'/etc/hysteria/config.json' <<EOF
{
  "listen": ":8081",
  "cert": "/etc/v2ray/origin.pem",
  "key": "/etc/v2ray/origin.key",
  "up_mbps": 1000,
  "down_mbps": 1000,
  "alpn": "h3",
    "disable_udp": false, 
      "auth": {
    "mode": "passwords",
    "config": [""]
  },
    "resolver": "udp://1.1.1.1:53",
  "resolve_preference": "4",
  "socks5_outbound": {
    "server": ""
  }
}
EOF
service hysteria-server stop


clear
echo "*******************************************************************"
echo -e "${Red} 用户域名：${Font} ${yoursite}"
echo -e "${Red} 用户id（UUID）：${Font} ${UUID}"
echo -e "${Red} ss密码是${sspass}"
echo -e "${Red} Public Key is ：${Font} ${publickey}"
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

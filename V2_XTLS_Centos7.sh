#初始环境
environment(){

read -p " 请输入你的网址:" yoursite


yum update -y
yum install wget curl unzip tar policycoreutils-python  rng-tools vim firewalld cron epel-release -y

rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel install kernel-ml -y
grub2-mkconfig -o /boot/grub2/grub.cfg
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
grub2-set-default 0

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
sed -i "/\"password\"/c \\\t  \"password\":\"${UUID}\"," /etc/xray/config.json


}

#Firewall
firewall(){
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --zone=public --add-port=22222/tcp
firewall-cmd --permanent --zone=public --add-port=80/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
firewall-cmd --permanent --zone=public --add-port=2096/tcp
firewall-cmd --reload
}


ssha(){
cd /root
mkdir .ssh/
read -p " 请输入你的KEY:" key
echo $key >> /root/.ssh/authorized_keys
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/g' /etc/ssh/sshd_config
echo "PasswordAuthentication no">>/etc/ssh/sshd_config
echo "PubkeyAuthentication yes">>/etc/ssh/sshd_config
echo "Port 22222">>/etc/ssh/sshd_config
semanage port -a -t ssh_port_t -p tcp 22222

systemctl restart sshd.service

}


#LNMP一键
v2_nginx(){

yum -y install vixie-cron
yum -y install crontabs
systemctl start crond.service

yum install -y curl vim wget unzip apt-transport-https lsb-release ca-certificates git gnupg2 netcat socat epel-release

mkdir /etc/xray
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m jsaafsdafaxcz@gmail1.com
~/.acme.sh/acme.sh --issue -d $yoursite --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $yoursite --fullchainpath /etc/xray/v2ray.crt --keypath /etc/xray/v2ray.key --ecc

(echo "59 23 * * * service nginx stop >> /dev/null 2>&1" ; crontab -l ) | crontab
(echo "1 1 * * * service nginx start >> /dev/null 2>&1" ; crontab -l ) | crontab



yum install -y nginx
systemctl enable nginx

mkdir /var/www
mkdir /var/www/site
cd /srv
wget https://github.com/zhangxiang958/Tour4U/archive/dev.zip
unzip dev.zip -d /var/www/site/

#config
wget --no-check-certificate -O /etc/nginx/conf.d/site.conf https://github.com/Lightmani/Docker_NetTools/raw/master/config/site.conf
sed -i "/server_name/c \\\t  server_name $yoursite;" /etc/nginx/conf.d/site.conf
sed -i "/http_host = \"\"/c \\\t  \$http_host = \"$yoursite\"" /etc/nginx/conf.d/site.conf



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
echo -e "
wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
chmod 755 /opt/bbr.sh
/opt/bbr.sh
"
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

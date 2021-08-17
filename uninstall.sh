yum remove nginx -y
apt remove nginx -y
apt autoremove -y
systemctl disable nginx
rm -rf /etc/nginx

acme.sh --uninstall

docker stop v2ray
docker rm v2ray
docker rmi teddysun/xray
rm -rf /etc/xray/

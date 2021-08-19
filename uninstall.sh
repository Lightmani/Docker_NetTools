yum remove nginx -y
apt remove nginx -y
apt autoremove -y
systemctl disable nginx
rm -rf /etc/nginx
apt remove caddy -y
rm -rf /etc/caddy/
acme.sh --uninstall

docker stop v2ray
docker rm v2ray
docker rmi teddysun/xray
docker rmi teddysun/v2ray
rm -rf /etc/xray/
rm -rf /etc/v2ray/

yum remove nginx -y
apt remove nginx -y
systemctl disable nginx

 acme.sh --uninstall

docker stop v2ray
docker rm v2ray

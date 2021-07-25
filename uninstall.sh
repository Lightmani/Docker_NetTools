yum remove nginx -y
apt remove nginx -y
systemctl disable nginx

docker stop v2ray
docker rm v2ray

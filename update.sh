service nginx stop

"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh"
chmod 755 /etc/v2ray/*
cat /etc/v2ray/v2ray.crt /etc/v2ray/v2ray.key > /etc/v2ray/v2ray.pem

service v2ray restart
service haproxy restart
service nginx start

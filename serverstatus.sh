#!/bin/bash
# 获取用户输入
read -p "请输入目标Host: " TARGET_HOST
read -p "请输入用户名: " USERNAME
read -sp "请输入密码: " PASSWORD
echo

apt install -y vnstat
systemctl restart vnstat
systemctl enable vnstat

WORKSPACE=/opt/ServerStatus
mkdir -p ${WORKSPACE}
cd ${WORKSPACE}

# 判断机器架构
if [[ "$(uname -m)" == "x86_64" ]]; then
    OS_ARCH="x86_64"
else
    OS_ARCH="aarch64"
fi

# 下载最新版本
latest_version=$(curl -m 10 -sL "https://api.github.com/repos/zdz/ServerStatus-Rust/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

# 根据架构下载相应的文件
curl -LO "https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/ServerStatus-${OS_ARCH}.tar.gz"
wget --no-check-certificate -qO "client-${OS_ARCH}-unknown-linux-musl.zip" "https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/client-${OS_ARCH}-unknown-linux-musl.zip"
unzip -o "client-${OS_ARCH}-unknown-linux-musl.zip"


# 创建service文件
SERVICE_FILE="/etc/systemd/system/stat_client.service"
cat <<EOF > ${SERVICE_FILE}
[Unit]
Description=ServerStatus-Rust Client
After=network.target

[Service]
User=root
Group=root
Environment="RUST_BACKTRACE=1"
WorkingDirectory=${WORKSPACE}
ExecStart=/opt/ServerStatus/stat_client -a "${TARGET_HOST}report" -u "${USERNAME}" -p "${PASSWORD}" -n --cm gd.ac.10086.cn:80 --ct www.02010010.com:80 --cu haosuan.com:80
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd，启用并启动服务
systemctl daemon-reload

systemctl enable stat_client
systemctl start stat_client

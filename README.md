# Docker_NetTools
使用Docker简单配置加密通讯程序

########
Docker 安装Shadowsocks+Gost隧道
Gost采用开启多路复用的Websocket隧道
SS密码使用随机生成的UUID

一键脚本（目前仅支持Ubuntu18+/Debian9+）：

apt install wget -y && wget --no-check-certificate -O /opt/ss.sh https://git.io/JUWsl && chmod 755 && bash /opt/ss.sh

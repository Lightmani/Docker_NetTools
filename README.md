# Docker_NetTools

安装探针

wget https://raw.githubusercontent.com/cokemine/ServerStatus-Hotaru/master/status.sh && bash status.sh c


使用Docker简单配置加密通讯程序

###################################################################

1、Shadowsocks（AEAD加密）+Gost隧道

目前仅支持Ubuntu18+/Debian9+

Gost采用开启多路复用的Websocket隧道

SS默认使用AEAD加密，密码使用随机生成的UUID

运行：

apt install wget -y && wget --no-check-certificate -O /opt/ss.sh https://git.io/JUWsl && chmod 755 /opt/ss.sh && bash /opt/ss.sh

2、Xray For Debian/Ubuntu

apt install wget -y && wget --no-check-certificate -O /opt/v2.sh https://raw.githubusercontent.com/Lightmani/Docker_NetTools/master/Docker_V2_Xtls.sh && chmod 755 /opt/v2.sh && bash /opt/v2.sh

3. Xray For Centos

yum install wget -y && wget --no-check-certificate -O /opt/v2.sh https://github.com/Lightmani/Docker_NetTools/raw/master/V2_XTLS_Centos7.sh && chmod 755 /opt/v2.sh && bash /opt/v2.sh

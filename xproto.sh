#!/bin/bash
echo ""
echo "Configuration script starting"
echo ""

#Requesting user input for domain name and email

read -p "Enter a domain name: " domain
[[ $domain =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$ ]] && echo "Proceeding" && echo "" || { echo "Invalid domain name, exiting..."; exit 1; }

read -p "Enter an email address: " email
[[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && echo "Proceeding" && echo "" || { echo "Invalid email address, exiting..."; exit 1; }

#Defining paths || Configuration password variables are defined in other part
#
#    Creating path variables
domain_certificate_path=/etc/letsencrypt/live/$domain/fullchain.pem
domain_privatekey_path=/etc/letsencrypt/live/$domain/privkey.pem

#Installing tools

command -v ifconfig &> /dev/null || apt install net-tools -y
#    Installing Curl
command -v curl &> /dev/null ||  apt install curl -y
#
#    Installing Docker
command -v docker &> /dev/null || { curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; }
#
#    Installing UUID generator
command -v uuidgen &> /dev/null || apt install uuid-runtime -y
#
#    Installing Certbot
command -v certbot &> /dev/null || apt install certbot -y
#
#    Installing QREncode
command -v qrencode &> /dev/null || apt install qrencode -y

#Obtaining server IPs
#    Obtaining IPv4
server_ipv4=$(ip -4 addr show $(ip route | awk '/default/ {print $5}') | awk '/inet/ {print $2}' | cut -d/ -f1)
#
#    Obtaining IPv6
server_ipv6=$(ip -6 addr show $(ip route | awk '/default/ {print $5}') | awk '/inet6/ {print $2}' | grep -v '^fe80' | cut -d/ -f1 | head -n 1)

#Create directory
mkdir -p /root/proxy

#Requesting SSL cerificate from Certbot
certbot certonly --standalone -d $domain --non-interactive --agree-tos --no-eff-email --email $email

#Create configuration files

#####hysteria2--------------------------------------------------hysteria2
#
#        Creating sub directory
mkdir -p /root/proxy/hysteria
#
#        Generating password
config_password_hysteria=$(openssl rand -base64 48 | tr '/+' 'xQ')
config_obfuscation_hysteria=$(openssl rand -base64 48 | tr '/+' 'xQ')
#
#        Creating server configuration file
port_hysteria=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
cat > /root/proxy/hysteria/config.json <<EOL
{
    "listen": ":443",
    "tls": {
        "cert": "$domain_certificate_path",
        "key": "$domain_privatekey_path",
        "sniGuard": "strict"
    },
    "obfs": {
        "type": "salamander",
        "salamander": {
            "password": "$config_obfuscation_hysteria"
        }
    },
    "bandwidth": {
        "up": "1 gbps",
        "down": "1 gbps"
    },
    "ignoreClientBandwidth": false,
    "speedTest": false,
    "disableUDP": false,
    "udpIdleTimeout": "120s",
    "auth": {
        "type": "password",
        "password": "$config_password_hysteria"
    },
    "sniff": {
        "enable": true,
        "timeout": "2s",
        "rewriteDomain": false,
        "tcpPorts": "80,443,8000-9000",
        "udpPorts": "all"
    },
    "masquerade": {
        "type": "proxy",
        "proxy": {
            "url": "https://baidu.com/",
            "rewriteHost": true
        }
    }
}
EOL
#
#        Creating client URI
cat > /root/proxy/hysteria/client <<EOL
hysteria2://$config_password_hysteria@$server_ipv4:$port_hysteria?sni=$domain&obfs=salamander&obfs-password=$config_obfuscation_hysteria
EOL

[[ -n "" ]] && touch ipv6_present.txt
#####shadowsocks--------------------------------------------------shadowsocks
#
#        Creating sub directory
mkdir -p /root/proxy/shadowsocks
#
#        Generating password
config_password_shadowsocks=$(openssl rand -base64 48 | tr '/+' 'xQ')
port_shadowsocks=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating server configuration file
cat > /root/proxy/shadowsocks/config.json <<EOL
{ 
  "server":"0.0.0.0", 
  "server_port":443, 
  "local_port":1080, 
  "password":"$config_password_shadowsocks", 
  "method":"chacha20-ietf-poly1305" 
}
EOL
#
#        Creating client URI
cat > /root/proxy/shadowsocks/client <<EOL
ss://$(echo -n chacha20-ietf-poly1305:$config_password_shadowsocks | base64 -w 0)@$server_ipv4:$port_shadowsocks?&tfo=1
EOL



#####juicity---------------------------------------------juicity
#
#        Creating sub directory
mkdir -p /root/proxy/juicity
#
#        Generating password and UUID
config_password_juicity=$(openssl rand -base64 48 | tr '/+' 'xQ')
config_uuid_juicity=$(uuidgen)
port_juicity=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating server configuration file
cat > /root/proxy/juicity/config.json <<EOL
{
  "listen": ":443",
  "users": {
    "$config_uuid_juicity": "$config_password_juicity"
  },
  "certificate": "$domain_certificate_path",
  "private_key": "$domain_privatekey_path",
  "congestion_control": "bbr",
  "log_level": "info"
}
EOL
#
#        Creating client URI
cat > /root/proxy/juicity/client <<EOL
juicity://$config_uuid_juicity:$config_password_juicity@$server_ipv4:$port_juicity?sni=$domain&congestion_control=bbr
EOL

#####trojan-----------------------------------------------trojan
#
#        Creating sub directory
mkdir -p /root/proxy/trojan
#
#        Generating password
config_password_trojan=$(openssl rand -base64 48 | tr '/+' 'xQ')
port_trojan=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating server configuration file
cat > /root/proxy/trojan/config.json <<EOL
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": "$config_password_trojan",
    "log_level": 1,
    "ssl": {
        "cert": "$domain_certificate_path",
        "key": "$domain_privatekey_path",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOL

#        Creating client URI
cat > /root/proxy/trojan/client <<EOL
trojan://$config_password_trojan@$server_ipv4:$port_trojan?peer=$domain&alpn=h2
EOL

#####brook--------------------------------------------------brook
#
#        Creating sub directory
mkdir -p /root/proxy/brook
#
#        Generating password
config_password_brook=$(openssl rand -base64 48 | tr '/+' 'xQ')
port_brook=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating server configuration file
cat > /root/proxy/brook/config.json <<EOL
{
  "listen": ":443",
  "password":"$config_password_brook",
  "domainaddress": "$domain",
  "cert": "$domain_certificate_path",
  "certkey": "$domain_privatekey_path",
  "udpTimeout": "120"
}
EOL
#
#        Creating client URI
cat > /root/proxy/brook/client <<EOL
brook://wssserver?wssserver=wss://$server_ipv4:$port_brook?/ws&param=%7B%22Host%22:%22$domain%22%7D&password=$config_password_brook
EOL

#####socks5------------------------------------------------socks5
#
#        Creating sub directory
mkdir -p /root/proxy/socks5
#
#        Generating password
config_password_socks5=$(openssl rand -base64 48 | tr '/+' 'xQ')
config_uuid_socks5=$(uuidgen)
port_socks5=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating configuration file
cat > /root/proxy/socks5/config.json <<EOL
{
  "listen": ":443",
  "users": {"$config_uuid_socks5": "$config_password_socks5"},
}
EOL
#
#        Creating client URI
cat > /root/proxy/socks5/client <<EOL
socks://$(echo -n $config_uuid_socks5:$config_password_socks5@$server_ipv4:$port_socks5 | base64 -w 0)
EOL

#####snell-------------------------------------------------snell
#
#        Creating sub directory
mkdir -p /root/proxy/snell
#
#        Generating password
config_password_snell=$(openssl rand -base64 48 | tr '/+' 'xQ')
port_snell=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating configuration file
cat > /root/proxy/snell/config.ini <<EOL
[snell-server]
listen = 0.0.0.0:443
psk = $config_password_snell
obfs = tls
obfs-host = www.baidu.com
ipv6 = true
reuse-port = true
udp = true
udp-max-size = 4096
timeout = 600
dns = 1.1.1.1,1.0.0.1
EOL
#
#        Creating client URI
cat > /root/proxy/snell/client <<EOL
snell://$(echo -n "chacha20-ietf-poly1305:$config_password_snell" | base64 -w 0)@$server_ipv4:$port_snell?plugin=obfs-local;obfs=tls;obfs-host=%7B%22Host%22:%22www.baidu.com%22%7D;obfs-uri=/&tfo=1
EOL

#####tuic-------------------------------------------------tuic
#
#        Creating sub directory
mkdir -p /root/proxy/tuic
#
#        Generating password
config_password_tuic=$(openssl rand -base64 48 | tr '/+' 'xQ')
config_uuid_tuic=$(uuidgen)
port_tuic=$((10000 + RANDOM % 55535)) #Port on the host, not in the container
#
#        Creating configuration file
cat > /root/proxy/tuic/config.json <<EOL
{
    "server": "[::]:443",
    "users": {
        "$config_uuid_tuic": "$config_password_tuic"
    },
    "certificate": "$domain_certificate_path",
    "private_key": "$domain_privatekey_path",
    "congestion_control": "bbr",
    "alpn": ["h3"],
    "udp_relay_ipv6": true,
    "zero_rtt_handshake": false,
    "dual_stack": true,
    "auth_timeout": "3s",
    "task_negotiation_timeout": "3s",
    "max_idle_time": "10s",
    "send_window": 16777216,
    "receive_window": 8388608,
    "gc_interval": "3s",
    "gc_lifetime": "15s",
    "log_level": "info"
}
EOL
#
#        Creating client URI
cat > /root/proxy/tuic/client <<EOL
tuic://$config_uuid_tuic:$config_password_tuic@$server_ipv4:$port_tuic?sni=$domain&congestion_control=bbr&alpn=h3&upd_relay_mode=native
EOL





#                          Creating containers

#####hysteria2--------------------------------------------------hysteria2
[[ $(docker ps -aq -f name=hysteria2) ]] && docker rm hysteria2 -f ; docker run --name hysteria2 \
-p $port_hysteria:443 \
-p $port_hysteria:443/udp \
-v /root/proxy/hysteria/config.json:/root/proxy/hysteria/config.json \
-v $domain_certificate_path:$domain_certificate_path \
-v $domain_privatekey_path:$domain_privatekey_path \
--restart unless-stopped \
-d tobyxdd/hysteria:v2 server -c /root/proxy/hysteria/config.json

#####shadowsocks----------------------------------------------shadowsocks
[[ $(docker ps -aq -f name=shadowsocks) ]] && docker rm shadowsocks -f ; docker run --name shadowsocks \
-p $port_shadowsocks:443 \
-p $port_shadowsocks:443/udp \
-v /root/proxy/shadowsocks/config.json:/etc/shadowsocks-libev/config.json \
--restart unless-stopped \
-d shadowsocks/shadowsocks-libev:v3.3.5 ss-server -c /etc/shadowsocks-libev/config.json

#####juicity-----------------------------------------------------juicity
[[ $(docker ps -aq -f name=juicity) ]] && docker rm juicity -f ; docker run --name juicity \
-p $port_juicity:443 \
-p $port_juicity:443/udp \
-v /root/proxy/juicity/config.json:/etc/juicity/server.json \
-v $domain_certificate_path:$domain_certificate_path \
-v $domain_privatekey_path:$domain_privatekey_path \
--restart unless-stopped \
-dt ghcr.io/juicity/juicity:v0.4.3

#####trojan-------------------------------------------------------trojan
[[ $(docker ps -aq -f name=trojan) ]] && docker rm trojan -f ; docker run --name trojan \
-p $port_trojan:443 \
-p $port_trojan:443/udp \
-v /root/proxy/trojan/config.json:/config/config.json \
-v $domain_certificate_path:$domain_certificate_path \
-v $domain_privatekey_path:$domain_privatekey_path \
--restart unless-stopped \
-dit trojangfw/trojan:latest


#####brook---------------------------------------------------------brook
[[ $(docker ps -aq -f name=brook) ]] && docker rm brook -f ; docker run --name brook \
-p $port_brook:443 \
-p $port_brook:443/udp \
-v $domain_certificate_path:$domain_certificate_path \
-v $domain_privatekey_path:$domain_privatekey_path \
--restart unless-stopped \
-d txthinking/brook:latest wssserver -p $config_password_brook --domainaddress $domain:443 --cert $domain_certificate_path --certkey $domain_privatekey_path --udpTimeout 120

#####socks5-------------------------------------------------------socks5
[[ $(docker ps -aq -f name=socks5) ]] && docker rm socks5 -f ; docker run --name socks5 \
-p $port_socks5:443 \
-p $port_socks5:443/udp \
--restart unless-stopped \
-dt lezamin/socks5:v1.0 -u $config_uuid_socks5 -P $config_password_socks5 -p 443

#####snell---------------------------------------------------------snell
[[ $(docker ps -aq -f name=snell) ]] && docker rm snell -f ; docker run --name snell \
-p $port_snell:443 \
-p $port_snell:443/udp \
-v /root/proxy/snell/config.ini:/etc/snell/snell-server.conf \
--restart unless-stopped \
-d echoer/snell:3.0.1

#####tuic----------------------------------------------------------tuic
[[ $(docker ps -aq -f name=tuic) ]] && docker rm tuic -f ; docker run --name tuic \
-p $port_tuic:443 \
-p $port_tuic:443/udp \
-v /root/proxy/tuic/config.json:/etc/tuic/config.json \
-v $domain_certificate_path:$domain_certificate_path \
-v $domain_privatekey_path:$domain_privatekey_path \
--restart unless-stopped \
-dit tinyserve/tuic:v1.1.2-fix1

########################################################################
echo ""
echo ""
echo ""
echo "HYSTERIA2-----------HYSTERIA2"
qrencode -t UTF8 $(cat /root/proxy/hysteria/client)
echo $(cat /root/proxy/hysteria/client)
echo ""
echo "SHADOWSOCKS-------SHADOWSOCKS"
qrencode -t UTF8 $(cat /root/proxy/shadowsocks/client)
echo $(cat /root/proxy/shadowsocks/client)
echo ""
echo "JUICITY---------------JUICITY"
qrencode -t UTF8 $(cat /root/proxy/juicity/client)
echo $(cat /root/proxy/juicity/client)
echo ""
echo "TROJAN-----------------TROJAN"
qrencode -t UTF8 $(cat /root/proxy/trojan/client)
echo $(cat /root/proxy/trojan/client)
echo ""
echo "BROOK-------------------BROOK"
qrencode -t UTF8 $(cat /root/proxy/brook/client)
echo $(cat /root/proxy/brook/client)
echo ""
echo "SOCKS5-----------------SOCKS5"
qrencode -t UTF8 $(cat /root/proxy/socks5/client)
echo $(cat /root/proxy/socks5/client)
echo ""
echo "SNELL-------------------SNELL"
qrencode -t UTF8 $(cat /root/proxy/snell/client)
echo $(cat /root/proxy/snell/client)
echo ""
echo "TUIC---------------------TUIC"
qrencode -t UTF8 $(cat /root/proxy/tuic/client)
echo $(cat /root/proxy/tuic/client)
echo ""
echo ""
echo ""
echo "Server setup has been completed, configuration URIs are provided above"

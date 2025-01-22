# XPROTO - Multi proxy protocol server setup

This script installs 8 proxy protocols using docker:
- HYSTERIA2
- SHADOWSOCKS
- JUICITY
- TROJAN
- BROOK
- SOCKS5
- SNELL
- TUIC5

The script can be ran using the following command:
```
bash <(curl -fsSL https://raw.githubusercontent.com/Babybatrick/xproto/refs/heads/main/xproto.sh -o xproto.sh)
```

Before running the script, make sure you have a domain, and have made an A record pointing to the server IP address

The script will request input of a domain and an email address

Recommended mobile client software for testing the protocols is `Shadowrocket`

Tested on Debian 12

# XPROTO - Установка прокси протоколов на сервер

Этот скрипт устанавливает 8 прокси протоколов с помощью docker:
- HYSTERIA2
- SHADOWSOCKS
- JUICITY
- TROJAN
- BROOK
- SOCKS5
- SNELL
- TUIC5

Для загрузки файла скрипта, используйте команду:
```
bash <(curl -fsSL https://raw.githubusercontent.com/Babybatrick/xproto/refs/heads/main/xproto.sh -o xproto.sh)
```

Перед исполнением скрипта, убедитесь что вы имеете домен, а также создали А запись указывающую на IP адрес сервера

Скрипт попросит вас ввести ваш домен и почтовый адрес

Для тестирования протоколов, рекомендуется использование мобильного клиента `Shadowrocket`

Протестировано на Debian 12

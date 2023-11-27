# VPN
Задание:
1) Между двумя виртуалками поднять vpn в режимах
- tun;
- tap;
Прочуствовать разницу.
2) Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку.
## Tun, tap режимы
На развернутых ВМ уже установлены openvpn, iperf, сгенерированы файлы ключа и конфигурационные файлы для обоих режимов.
### TAP
Проверим работу в режиме `tap`:
Запустим на сервере
```
[root@server ~]# systemctl start openvpn@server-tap
[root@server ~]# iperf3 -s &
```
Запустим на клиенте
```
[root@client ~]# systemctl start openvpn@client-tap
[root@client ~]# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 39782 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  44.2 MBytes  74.1 Mbits/sec  494    244 KBytes
[  5]   5.00-10.00  sec  40.0 MBytes  67.1 Mbits/sec   44    259 KBytes
[  5]  10.00-15.00  sec  33.8 MBytes  56.6 Mbits/sec    0    339 KBytes
[  5]  15.00-20.01  sec  33.8 MBytes  56.5 Mbits/sec    0    835 KBytes
[  5]  20.01-25.00  sec  36.2 MBytes  61.0 Mbits/sec  250    202 KBytes
[  5]  25.00-30.00  sec  41.2 MBytes  69.2 Mbits/sec  118    142 KBytes
[  5]  30.00-35.00  sec  48.8 MBytes  81.8 Mbits/sec   91    153 KBytes
[  5]  35.00-40.01  sec  46.2 MBytes  77.5 Mbits/sec   28    165 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.01  sec   324 MBytes  68.0 Mbits/sec  1025             sender
[  5]   0.00-40.11  sec   321 MBytes  67.2 Mbits/sec                  receiver

iperf Done.
```
Остановим сервис openvpn на клиенте и сервере `systemctl stop openvpn@*`
### TUN
Проверим работу в режиме `tun`:
Запустим на сервере
```
[root@server ~]# systemctl start openvpn@server-tun
```
Запустим на клиенте
```
[root@client ~]# systemctl start openvpn@client-tun
[root@client ~]# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 53460 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  81.1 MBytes   136 Mbits/sec  187    277 KBytes
[  5]   5.00-10.00  sec  77.3 MBytes   130 Mbits/sec   32    227 KBytes
[  5]  10.00-15.00  sec  75.8 MBytes   127 Mbits/sec   74    145 KBytes
[  5]  15.00-20.00  sec  47.8 MBytes  80.2 Mbits/sec    0    299 KBytes
[  5]  20.00-25.00  sec  45.4 MBytes  76.1 Mbits/sec   93    259 KBytes
[  5]  25.00-30.00  sec  53.6 MBytes  89.9 Mbits/sec   70    250 KBytes
[  5]  30.00-35.00  sec  55.1 MBytes  92.4 Mbits/sec  130    172 KBytes
[  5]  35.00-40.00  sec  42.2 MBytes  70.8 Mbits/sec    0    299 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   478 MBytes   100 Mbits/sec  586             sender
[  5]   0.00-40.21  sec   476 MBytes  99.4 Mbits/sec                  receiver

iperf Done.
```

По итогам сравнения работы openvpn в разных режимах можно отметить, что в режиме tap достигается меньшая пропускная способность при нагрузочном тестировании с iperf. Э то связано с тем, что в данном режиме эмулируется  сетевой адаптер, передающий кадры Ethernet, что может быть полезно для работы протоколов, требующих L2-связности и широковещания, но в комплекте мы получаем и больше издержек и накладных расходов при передаче трафика. Tun режим по сути работает с IP-пакетами в режиме точка-точка.

## RAS
Переходим в директорию /etc/openvpn/ и инициализируем pki, генерируем сертификаты для сервера
```
[root@server ~]# cd /etc/openvpn/
[root@server openvpn]# /usr/share/easy-rsa/3.1.5/easyrsa init-pki
...
[root@server openvpn]# echo 'rasvpn' | /usr/share/easy-rsa/3.1.5/easyrsa build-ca nopass
...
[root@server openvpn]# echo 'rasvpn' | /usr/share/easy-rsa/3.1.5/easyrsa gen-req server nopass
...
[root@server openvpn]# echo 'yes' | /usr/share/easy-rsa/3.1.5/easyrsa sign-req server server
...
[root@server openvpn]# /usr/share/easy-rsa/3.1.5/easyrsa gen-dh
...
[root@server openvpn]# openvpn --genkey secret ca.key
```
Сгенерируем сертификаты для клиента, и зададим параметр для внутреннего маршрута
```
[root@server openvpn]# echo 'client' | /usr/share/easy-rsa/3/easyrsa gen-req client nopass
[root@server openvpn]# echo 'yes' | /usr/share/easy-rsa/3/easyrsa sign-req client client
[root@server openvpn]# echo 'iroute 10.10.10.0 255.255.255.0' > /etc/openvpn/client/client
```
Скопируем на хост файлы сертификатов и ключ для клиента на хост-машину
```
[root@server ~]# cp /etc/openvpn/pki/ca.crt /vagrant/
[root@server ~]# cp /etc/openvpn/pki/issued/client.crt /vagrant/
[root@server ~]# cp /etc/openvpn/pki/private/client.key /vagrant/
```
Добавим порт 1207 к разрешенным и запустим сервис OpenVPN на сервере 
```
[root@server ~]# semanage port -a -t openvpn_port_t -p udp 1207
[root@server ~]# systemctl start openvpn@server-ras
```
Настроим теперь все на хост-машине
```
[kgeor@rocky-ls lab22]$ sudo dnf install openvpn
Last metadata expiration check: 0:42:10 ago on Thu 24 Aug 2023 05:22:59 PM MSK.
Package openvpn-2.5.9-1.el9.x86_64 is already installed.
...

[kgeor@rocky-ls lab22]$ echo 'dev tun
proto udp
cipher AES-256-CBC
remote 192.168.56.10 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
route 10.10.10.0 255.255.255.0
persist-key
persist-tun
compress lz4
verb 3' | sudo tee /etc/openvpn/client.conf > /dev/null
```
Запускаем и проверяем
```
[kgeor@rocky-ls openvpn]$ sudo openvpn --config client.conf &
[kgeor@rocky-ls openvpn]$ ip route
default via 10.0.0.1 dev ens33 proto static metric 100
10.0.0.0/8 dev ens33 proto kernel scope link src 10.0.22.29 metric 100
10.10.10.0/24 via 10.10.10.5 dev tun0
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6
192.168.56.0/24 dev vboxnet0 proto kernel scope link src 192.168.56.2

[kgeor@rocky-ls openvpn]$ ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.609 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.536 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.559 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=0.518 ms
^C
--- 10.10.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3074ms
rtt min/avg/max/mdev = 0.518/0.555/0.609/0.034 ms
```
Все работает корректно.

**PROFIT!!!**

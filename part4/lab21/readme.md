# OSPF
Топология развернутого стенда

![лог_топология](./images/topo.png)

На развернутом стенде из 3 маршрутизаторов адресация и маршрутизация уже полностью настроены согласно топологии выше.

для проверки корректности настройки просмотрим отношения смежности в интерфейсе FRR.
```
root@router3:~# vtysh
router3# sh ip ospf neighbor

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
2.2.2.2           1 Full/DR         17m31s            28.643s 10.0.11.2       enp0s8:10.0.11.1                     0     0     0
1.1.1.1           1 Full/DR         17m25s            28.643s 10.0.12.1       enp0s9:10.0.12.2                     0     0     0
```
Отношения успешно установлены между всеми маршрутизаторами, информация между ними полностью синхронизирована.

Проверим таблицы маршрутизации и проверим доступность удаленных (не directly connected) сетей.
```
root@router3:~# ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
10.0.2.2 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100
10.0.2.3 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100
10.0.10.0/30 nhid 41 proto ospf metric 20
        nexthop via 10.0.11.2 dev enp0s8 weight 1
        nexthop via 10.0.12.1 dev enp0s9 weight 1
10.0.11.0/30 dev enp0s8 proto kernel scope link src 10.0.11.1
10.0.12.0/30 dev enp0s9 proto kernel scope link src 10.0.12.2
192.168.10.0/24 nhid 42 via 10.0.12.1 dev enp0s9 proto ospf metric 20
192.168.20.0/24 nhid 34 via 10.0.11.2 dev enp0s8 proto ospf metric 20
192.168.30.0/24 dev enp0s10 proto kernel scope link src 192.168.30.1
192.168.56.0/24 dev enp0s16 proto kernel scope link src 192.168.56.12

root@router3:~# ping 192.168.10.1
PING 192.168.10.1 (192.168.10.1) 56(84) bytes of data.
64 bytes from 192.168.10.1: icmp_seq=1 ttl=64 time=0.562 ms
64 bytes from 192.168.10.1: icmp_seq=2 ttl=64 time=1.23 ms
^C
--- 192.168.10.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1080ms
rtt min/avg/max/mdev = 0.562/0.897/1.232/0.335 ms

root@router3:~# ping 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=0.584 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.480 ms
^C
--- 192.168.20.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1025ms
rtt min/avg/max/mdev = 0.480/0.532/0.584/0.052 ms
```
Маршрутизация настроена корректно, трафик свободно проходит до удаленных сетей.

**PROFIT!!!**
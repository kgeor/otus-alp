# DNS
Задание:
1) взять стенд https://github.com/erlong15/vagrant-bind
2) добавить еще один сервер client2
3) завести в зоне dns.lab имена
- web1 - смотрит на клиент1
- web2 смотрит на клиент2
4) завести еще одну зону newdns.lab
5) завести в ней запись www - смотрит на обоих клиентов
6) настроить split-dns
- клиент1 - видит обе зоны, но в зоне dns.lab только web1
- клиент2 видит только dns.lab
7) настроить все без выключения selinux*
  
Первые два подпункта отчета о выполнении для наглядности описывают ручное приведение всей системы к требуемому состоянию (конфигурация и зоны DNS взяты из https://github.com/erlong15/vagrant-bind), но при запуске стенда, Ansible сразу сконфигурирует все хосты так, как требуется по заданию, поэтому никакой доп. конфигурации производить не нужно, сразу можно переходить к подпункту Проверка. 
## Настройка DNS,добавление записей в зону
После развертывания зайдем на мастер `vagrant ssh ns01` и проверим, что DNS-сервер запущен и прослушивает запросы из сети
```
[vagrant@ns01 ~]$ ss -ulpn
State    Recv-Q   Send-Q       Local Address:Port       Peer Address:Port   Process
UNCONN   0        0            192.168.50.10:53              0.0.0.0:*
...
```
На все том же главном сервере в зону `dns.lab` добавим вручную пару записей
```
[root@ns01 ~]# cat << 'EOF' >> /etc/named/named.dns.lab
;Web
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
EOF
[root@ns01 ~]# sed -i 's/2711201407/2711201408/' /etc/named/named.dns.lab
[root@ns01 ~]# systemctl restart named
```
Проверим с клиента `client01`, что новые записи в зоне появились, в т.ч. на подчиненном сервере
```
[vagrant@client01 ~]$ dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4741
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: b5f0e53e59af06460100000064ca358bc56acf8a89ddac33 (good)
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; ANSWER SECTION:
web1.dns.lab.           3600    IN      A       192.168.50.15

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Aug 25 00:29:00 MSK 2023
;; MSG SIZE  rcvd: 85
[vagrant@client01 ~]$ dig @192.168.50.11 web2.dns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 27823
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 58674e97fa9245c60100000064ca408c45c1f44493cc2ce1 (good)
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; ANSWER SECTION:
web2.dns.lab.           3600    IN      A       192.168.50.16

;; Query time: 2 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Fri Aug 25 00:29:48 MSK 2023
;; MSG SIZE  rcvd: 85
```

##  Добавление зоны DNS
На `ns01` добавим описание зоны в файл конфигурации BIND, плюс файл с записями зоны
```
[root@ns01 ~]# cat << 'EOF' >> /etc/named.conf
// lab's newdns zone
zone "newdns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    allow-update { key "zonetransfer.key"; };
    file "/etc/named/named.newdns.lab";
};
EOF
[root@ns01 ~]# cat << 'EOF' > /etc/named/named.newdns.lab
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201007 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;WWW
www             IN      A       192.168.50.15
www             IN      A       192.168.50.16
EOF
[root@ns01 ~]# chown root:named /etc/named/named.newdns.lab
[root@ns01 ~]# chmod 0660 /etc/named/named.newdns.lab
```
Изменим значение `serial` для новой зоны и перезапустим сервис `named` 
```
[root@ns01 ~]# sed -i 's/2711201007/2711201008/' /etc/named/named.newdns.lab
[root@ns01 ~]# systemctl restart named
```
На `ns02` просто в файле конфигурации BIND укажем новую зону и перезапустим сервис `named`, подчиненный сервер сам синхронизируется с мастером
```
[root@ns02 ~]# cat << 'EOF' >> /etc/named.conf
// lab's newdns zone
zone "newdns.lab" {
    type slave;
    masters { 192.168.50.10; };
    file "/etc/named/named.newdns.lab";
};
EOF
[root@ns02 ~]# systemctl restart named
[root@ns02 ~]# dig www.newdns.lab

; <<>> DiG 9.16.23-RH <<>> www.newdns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 2431
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 0d5a8b7bd4efe8480100000064e7cf4e490a9acb60253c97 (good)
;; QUESTION SECTION:
;www.newdns.lab.                        IN      A

;; ANSWER SECTION:
www.newdns.lab.         3600    IN      A       192.168.50.15
www.newdns.lab.         3600    IN      A       192.168.50.16

;; Query time: 1 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Fri Aug 25 00:44:46 MSK 2023
;; MSG SIZE  rcvd: 103
```
Новая зона успешно синхронизирована.

## Split-DNS
На `ns01` добавим отдельный файл зоны dns.lab без записи web2
```
[root@ns01 ~]# cat << 'EOF' > /etc/named/named.dns.lab.client
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web
web1            IN      A       192.168.50.15
EOF
[root@ns01 ~]# chown root:named /etc/named/named.dns.lab.client
[root@ns01 ~]# chmod 0660 /etc/named/named.dns.lab.client
```
Скопируем файл конфигурации BIND с прописанными view и acl на оба сервера
```
[root@ns01 ~]# cp /vagrant/ansible/files/master-named-final.conf /etc/named.conf
...
[root@ns02 ~]# cp /vagrant/ansible/files/slave-named-final.conf /etc/named.conf
```
На обоих серверах перезапустим `named`поочередно 
```
[root@ns01 ~]# systemctl restart named
...
[root@ns02 ~]# systemctl restart named
...
```
## Проверка
C клиентов проверим возможность разрешения имен
```
[root@client01 ~]#  ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client01 (192.168.50.15): icmp_seq=1 ttl=64 time=0.021 ms
...
[root@client01 ~]#  ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client01 (192.168.50.15): icmp_seq=1 ttl=64 time=0.039 ms
...
[root@client01 ~]#  ping web2.dns.lab
ping: web2.dns.lab: Name or service not known
```
client01 видит обе зоны (dns.lab и newdns.lab), однако информацию о хосте web2.dns.lab он получить не может
```
[root@client02 ~]# ping www.newdns.lab
ping: www.newdns.lab: Name or service not known
[root@client02 ~]# ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=1.26 ms
...
[root@client02 ~]# ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client02 (192.168.50.16): icmp_seq=1 ttl=64 time=0.038 ms
...
```
client2 видит всю зону dns.lab и не видит зону newdns.lab.

Проверим, что на подчиненном сервере конфигурация идентична
```
[root@client02 ~]# dig @192.168.50.11 www.newdns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.11 www.newdns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 57562
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
...
[root@client02 ~]# dig @192.168.50.11 web2.dns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 41870
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

```
Все работает как ожидается и на втором сервере.

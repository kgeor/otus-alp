# NFS, FUSE
Задание:
1) vagrant up должен поднимать 2 виртуалки: сервер и клиент;
2) на сервер должна быть расшарена директория;
3) на клиента она должна автоматически монтироваться при старте (fstab или autofs);
4) в шаре должна быть папка upload с правами на запись;
5) включенный firewall.
6) Задание со звездочкой* 
Настроить аутентификацию через KERBEROS (NFSv4)
## Настройка NFS-сервера с поддержкой Kerberos
Заходим на сервер `vagrant ssh nfss`

Установим пакет утилит для NFS и Kerberos аутентификации
```
[root@nfss ~]$ dnf install nfs-utils krb5-server krb5-workstation pam_krb5
```
Настроим сервер Kerberos для домена DOMAIN.LOCAL
```
[root@nfss ~]# cat << EOF >> /etc/hosts
192.168.50.10 nfss.domain.local nfss
192.168.50.11 nfsc.domain.local nfsc
EOF
[root@nfss ~]# sed -ie 's/#    default_realm = EXAMPLE.COM/    default_realm = DOMAIN.LOCAL/; s/# EXAMPLE.COM = {/DOMAIN.LOCAL = {/;
 s/#     kdc = kerberos.example.com/     kdc = nfss.domain.local/; s/#     admin_server = kerberos.example.com/     admin_server = nfss.domain.local/;
 s/# }/ }/; s/# .example.com = EXAMPLE.COM/ .domain.local = DOMAIN.LOCAL/; s/# example.com = EXAMPLE.COM/domain.local = DOMAIN.LOCAL/' /etc/krb5.conf
[root@nfss ~]# sed -i 's/EXAMPLE.COM/DOMAIN.LOCAL/' /var/kerberos/krb5kdc/kadm5.acl
[root@nfss ~]# kdb5_util create -s -P m@sterk3y
Loading random data
Initializing database '/var/kerberos/krb5kdc/principal' for realm 'DOMAIN.LOCAL',
master key name 'K/M@DOMAIN.LOCAL'
[root@nfss ~]# systemctl enable krb5kdc kadmin --now
```
Создадим на KDC принципалы хоста и NFS службы для сервера и клиента
```
[root@nfss ~]# kadmin.local -q "addprinc -randkey host/nfss.domain.local"
[root@nfss ~]# kadmin.local -q "addprinc -randkey host/nfsc.domain.local"
[root@nfss ~]# kadmin.local -q "addprinc -randkey nfs/nfss.domain.local"
[root@nfss ~]# kadmin.local -q "addprinc -randkey nfs/nfsc.domain.local"
```
Создадим keytab файлы для сервера и клиента, скопируем файл для клиента в общую папку
```
[root@nfss ~]# kadmin.local -q "ktadd host/nfss.domain.local"
[root@nfss ~]# kadmin.local -q "ktadd nfs/nfss.domain.local"
[root@nfss ~]# kadmin.local -q "ktadd -k /opt/krb5.keytab host/nfsc.domain.local"
[root@nfss ~]# kadmin.local -q "ktadd -k /opt/krb5.keytab nfs/nfsc.domain.local"
[root@nfss ~]# cp -f /opt/krb5.keytab /vagrant
```
Настроим firewall
```
[root@nfss ~]$ systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor>)
     Active: active (running) since Thu 2023-03-23 15:04:34 MSK; 24min ago
...
[root@nfss ~]# firewall-cmd ---add-service="nfs" \
--add-service="kerberos" \
--permanent
firewall-cmd --reload
success
success
```
Настроим экспорт директории для NFS
```
[root@nfss ~]# mkdir -p /srv/share/upload
[root@nfss ~]# chown -R nobody:nobody /srv/share
[root@nfss ~]# cat << EOF > /etc/exports
/srv/share 192.168.50.11(rw,sec=krb5p,sync)
EOF
```
Запустим NFS-сервер и создадим в экспортируемой директории тестовый файл
```
[root@nfss ~]# systemctl enable nfs-server --now
[root@nfss ~]# touch /srv/share/upload/check_s_file
```
Проверим, что нужные сетевые порты прослушиваются
```
[root@nfss ~]# ss -tulpn
Netid   State    Recv-Q   Send-Q     Local Address:Port      Peer Address:Port  Process
udp     UNCONN   0        0                0.0.0.0:20048          0.0.0.0:*      users:(("rpc.mountd",pid=46511,fd=4))
udp     UNCONN   0        0                0.0.0.0:88             0.0.0.0:*      users:(("krb5kdc",pid=46357,fd=8))
udp     UNCONN   0        0                0.0.0.0:111            0.0.0.0:*      users:(("rpcbind",pid=46492,fd=5),("systemd",pid=1,fd=51))
tcp     LISTEN   0        4096             0.0.0.0:111            0.0.0.0:*      users:(("rpcbind",pid=46492,fd=4),("systemd",pid=1,fd=50))
tcp     LISTEN   0        4096             0.0.0.0:20048          0.0.0.0:*      users:(("rpc.mountd",pid=46511,fd=5))
tcp     LISTEN   0        5                0.0.0.0:88             0.0.0.0:*      users:(("krb5kdc",pid=46357,fd=9))
tcp     LISTEN   0        64               0.0.0.0:2049           0.0.0.0:*     
```
Проверим, что настройки экспорта NFS применились
```
[root@nfss ~]# exportfs -s
/srv/share  192.168.50.11(sync,wdelay,hide,no_subtree_check,sec=krb5p,rw,secure,root_squash,no_all_squash)
```
## Настройка NFS-клиента с поддержкой Kerberos
Заходим на клиент `vagrant ssh nfsc`

Установим нужные пакеты
```
[root@nfsc ~]# dnf -y install nfs-utils krb5-workstation pam_krb5
```
Настроим Kerberos
```
[root@nfsc ~]# echo "192.168.50.10:/srv/share/ /mnt nfs sec=krb5p,noauto,_netdev,x-systemd.automount,x-systemd.mount-timeout=10,x-systemd.idle-timeout=1min 0 0" | tee -a /etc/fstab
192.168.50.10:/srv/share/ /mnt nfs sec=krb5p,noauto,_netdev,x-systemd.automount,x-systemd.mount-timeout=10,x-systemd.idle-timeout=1min 0 0
[root@nfsc ~]# cp /vagrant/krb5.keytab /etc/
[root@nfsc ~]# sed -ie 's/#    default_realm = EXAMPLE.COM/    default_realm = DOMAIN.LOCAL/; s/# EXAMPLE.COM = {/DOMAIN.LOCAL = {/;
 s/#     kdc = kerberos.example.com/     kdc = nfss.domain.local/; s/#     admin_server = kerberos.example.com/     admin_server = nfss.domain.local/;
 s/# }/ }/; s/# .example.com = EXAMPLE.COM/ .domain.local = DOMAIN.LOCAL/; s/# example.com = EXAMPLE.COM/domain.local = DOMAIN.LOCAL/' /etc/krb5.conf
```
Получим билет как для суперпользователя `root`, так и для обычного `vagrant`
```
[root@nfsc ~]# kinit -k -t /etc/krb5.keytab nfs/nfsc.domain.local
[root@nfsc ~]# sudo -u vagrant kinit -k -t /vagrant/krb5.keytab nfs/nfsc.domain.local
```
Проверим наличие билета Kerberos:
```
[root@nfsc ~]# klist
Ticket cache: KCM:0
Default principal: nfs/nfsc.domain.local@DOMAIN.LOCAL

Valid starting     Expires            Service principal
03/29/23 16:13:55  03/30/23 16:13:55  krbtgt/DOMAIN.LOCAL@DOMAIN.LOCAL
        renew until 03/29/23 16:13:55
```
Перезапустим сервисы и проверим монтирование
```
[root@nfsc ~]# systemctl daemon-reload
[root@nfsc ~]# systemctl restart remote-fs.target nfs-client.target
[root@nfsc ~]# ls -l /mnt/upload
total 0
-rw-r--r--. 1 root root 0 Mar 29 15:59 check_s_file
[root@nfsc ~]# touch /mnt/upload/check_c_file
[root@nfsc ~]# ls -l /mnt/upload
total 0
-rw-r--r--. 1 nobody nobody 0 Mar 29 16:21 check_c_file
-rw-r--r--. 1 root   root   0 Mar 29 15:59 check_s_file
```
**PROFIT!**

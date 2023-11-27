# Практика с SELinux
Задание:
1) Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux.
2) Обеспечить работоспособность приложения при включенном selinux.
- развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems (исправленный вариант в папке этого репо);
- выяснить причину неработоспособности механизма обновления зоны (см. README);
- предложить решение (или решения) для данной проблемы;
- выбрать одно из решений для реализации, предварительно обосновав выбор;
- реализовать выбранное решение и продемонстрировать его работоспособность.
## 1. Запустить NGINX на нестандартном порту 3-мя разными способами
Запукаем виртуальную машину с установкой в секции provision NGINX, работающего на нестандартном порту при включенном SELinux, в выводе vagrant о подготовке ВМ получаем
```
...
rocky9-selinux: May 02 13:54:22 rocky9-sel systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
...
```
NGINX не может запуститься, проверим состояние firewalld, SELinux и конфигурацию NGINX на корректность:
```
[root@rocky9-sel ~]# systemctl status firewalld
○ firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
...
[root@rocky9-sel ~]# getenforce
Enforcing
[root@rocky9-sel ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
Попробуем исправить данную ситуацию 3-мя разными способами
### 1. Переключатели setsebool
С помощью утилиты audit2why узнаем, какой переключатель необходимо включить для решения проблемы запуска NGINX
```
[root@rocky9-sel ~]# grep 1683024862.583:802 /var/log/audit/audit.log |audit2why
type=AVC msg=audit(1683024862.583:802): avc:  denied  { name_bind } for  pid=9319 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly.
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1
[root@rocky9-sel ~]# setsebool -P nis_enabled 1
[root@rocky9-sel ~]# systemctl restart nginx
[root@rocky9-sel ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
     Active: active (running) since Tue 2023-05-02 15:33:38 MSK; 10s ago
...
```
Все корректно работает, теперь выключим обратно переключатель и перейдем к следующему методу
```
[root@rocky9-sel ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
[root@rocky9-sel ~]# setsebool -P nis_enabled off
```
### 2. Добавление нестанлартного порта в имеющийся тип http
Проверим, какие порты включает встроенный тип http
```
[root@rocky9-sel ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```
Добавим свой порт к типу `http_port_t`, проверим список еще раз и попробуем стартовать службу NGINX
```
[root@rocky9-sel ~]# semanage port -l | grep ^http_port
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
[root@rocky9-sel ~]# systemctl restart nginx
[root@rocky9-sel ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
     Active: active (running) since Tue 2023-05-02 15:41:21 MSK; 3s ago
```
Все корректно работает, теперь удалим добавленный порт и перейдем к следующему методу
```
[root@rocky9-sel ~]# semanage port -d -t http_port_t -p tcp 4881
[root@rocky9-sel ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
```
### 3. Формирование и установка модуля SELINUX
```
[root@rocky9-sel ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

[root@rocky9-sel ~]# semodule -i nginx.pp
[root@rocky9-sel ~]# systemctl restart nginx
[root@rocky9-sel ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
     Active: active (running) since Tue 2023-05-02 15:45:49 MSK; 5s ago
```
Все снова корректно работает, теперь удалим модуль
```
[root@rocky9-sel ~]# semodule -r nginx
```
## 2. Обеспечение работоспособности приложения при включенном SELinux
склонируем git-репозиторий и запустим стенд
```
[kgeor@rocky-ls lab12]$ git clone https://github.com/mbfx/otus-linux-adm.git
[kgeor@rocky-ls lab12]$ cd otus-linux-adm/selinux_dns_problems
Добавим в vagrantfile внутрь секции config строки
```
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false  
  end
```
[kgeor@rocky-ls selinux_dns_problems]$ vagrant up
[kgeor@rocky-ls selinux_dns_problems]$ vagrant ssh client
```
Попробуем внести изменения в зону со стороны клиента
```
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
...
[root@client ~]# cat /var/log/audit/audit.log | audit2why
[root@client ~]#
```
Внести не получилось, на клиенте при этом ошибок, связанных с SELinux нет, проверим на сервере
```
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1683033037.541:1756): avc:  denied  { write } for  pid=5636 comm="isc-worker0000" name="dynamic" dev="dm-0" ino=100666197 scontext=system_u:system_r:named_t:s0 tcontext=unconfined_u:object_r:named_zone_t:s0 tclass=dir

        Was caused by:
        The boolean named_write_master_zones was set incorrectly.
        Description:
        Allow named to write master zones

        Allow access by executing:
        # setsebool -P named_write_master_zones 1

type=AVC msg=audit(1683033679.347:1781): avc:  denied  { create } for  pid=5636 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.
[root@ns01 ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
```
Видим, что есть ошибка, связанная с контекстом безопасности. Вместо типа named_t используется тип etc_t.
Проверим, в каком каталоге должны лежать файлы зоны, чтобы был корректный контекст.
```
[root@ns01 ~]# semanage fcontext -l | grep named
/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0
/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0
...
```
У нас несовпадение предполагаемого и фактического каталога с файлами зоны DNS, потому и контекст неверен. Изменим констекст для `/etc/named`
```
[root@ns01 ~]# chcon -R -t named_zone_t /etc/named
[root@ns01 ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:named_zone_t:s0 .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab
```
НО, еще присутствует ошибка о не включенном переключателе, который разрешил бы произвести запись в зону, исправим и ее
```
[root@ns01 ~]# setsebool -P named_write_master_zones 1
```
Снова попробуем внести изменения в зону с клиента
```
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[vagrant@client ~]$ dig www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.13 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 28049
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15
...
```
Проверка запросом к серверу подтвердила,что операция обновления зоны прошла успешно, запись теперь присутствует на сервере
**PROFIT!!!**

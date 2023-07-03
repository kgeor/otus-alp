# Сбор логов
Для примера развернуто 2 ВМ - веб-сервер (NGINX) и сервер логов (rsyslog).
Сервер логов настроен на прием логов rsyslog на 514 порту и логов auditd на 60 порту. Веб-сервер соответственно сконфигурирован на отправку access и error логов NGINX на удаленный rsyslog сервер и отправку сообщений аудита об изменении файлов конфигурации NGINX.

Проверим работоспособность, сделаем обращение к веб-серверу и проверим, что логи доступа приходят на сервер логов
```
[root@rocky9-log ~]# curl 10.0.5.11 > /dev/null
...
[root@rocky9-log ~]# cat /var/log/rsyslog/rocky9-web/nginx_access.log
Jun 23 13:41:28 rocky9-web nginx_access: 10.0.5.10 - - [23/Jun/2023:13:41:28 +0300] "GET / HTTP/1.1" 200 7620 "-" "curl/7.76.1"
```
На сервере удалим важный файл из директории сайта
```
[root@rocky9-web ~]# rm -f /usr/share/nginx/html/index.html
```
Снова обратимся к сайту и проверим, что лог доступа обновляется, а лог ошибок также приходит на сервер логов
```
[root@rocky9-log ~]# cat /var/log/rsyslog/rocky9-web/nginx_access.log
Jun 23 13:41:28 rocky9-web nginx_access: 10.0.5.10 - - [23/Jun/2023:13:41:28 +0300] "GET / HTTP/1.1" 200 7620 "-" "curl/7.76.1"
Jun 23 13:42:58 rocky9-web nginx_access: 10.0.5.10 - - [23/Jun/2023:13:42:58 +0300] "GET / HTTP/1.1" 403 153 "-" "curl/7.76.1"
[root@rocky9-log ~]# cat /var/log/rsyslog/rocky9-web/nginx_error.log
Jun 23 13:42:58 rocky9-web nginx_error: 2023/06/23 13:42:58 [error] 25957#25957: *2 directory index of "/usr/share/nginx/html/" is forbidden, client: 10.0.5.10, server: _, request: "GET / HTTP/1.1", host: "10.0.5.11"
```
Проверим работу сбора логов аудита, изменим атрибут файла конфигурации NGINX
```
[root@rocky9-web ~]# touch /etc/nginx/nginx.conf
...
[root@rocky9-log ~]# grep nginx_conf /var/log/audit/audit.log
node=rocky9-web type=CONFIG_CHANGE msg=audit(1687516822.386:1824): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
node=rocky9-web type=CONFIG_CHANGE msg=audit(1687516822.386:1825): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
node=rocky9-web type=SYSCALL msg=audit(1687517121.316:1886): arch=c000003e syscall=257 success=yes exit=3 a0=ffffff9c a1=7ffccb1fd796 a2=941 a3=1b6 items=2 ppid=42289 pid=48977 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts0 ses=5 comm="touch" exe="/usr/bin/touch" subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key="nginx_conf"
```
**PROFIT!!!**
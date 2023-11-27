# Инициализация системы. Systemd.
Задание:
1) Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig или в /etc/default).
2) Установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
3) Дополнить unit-файл httpd (он же apache2) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

Подготовим систему, выключим SELinux, firewalld
```
[root@r9-systemd ~]# setenforce 0
[root@r9-systemd ~]# sed -i 's/enforcing/disabled/' /etc/selinux/config
[root@r9-systemd ~]# systemctl stop firewalld
```
## Запуск сервиса по таймеру
Создадим файл окружения для сервиса мониторинга и файл лога, в котором сервис будет вести поиск
```
[root@r9-systemd ~]#  echo $'# File and word in that file that we will be monitored\nWORD="ALERT"\nLOG=/var/log/watchlog.log' > /etc/sysconfig/watchlog
[root@r9-systemd ~]# man echo > /var/log/watchlog.log
[root@r9-systemd ~]# echo 'ALERT' >> /var/log/watchlog.log
[root@r9-systemd ~]# grep 'ALERT' /var/log/watchlog.log
ALERT
```
Создадим скрипт `/opt/watchlog.sh` для проверки наличия слова в файле
```
[root@r9-systemd ~]# cat << 'EOF' > /opt/watchlog.sh
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
    logger "$DATE: I found the word, Master!"
else
    exit 0
fi
EOF
```
Добавим права на запуск файла скрипта и создадим файлы конфигурации юнита сервиса, вызывающего скрипт и  юнита таймера, запускающего сервис каждые 30с
```
[root@r9-systemd ~]# chmod +x /opt/watchlog.sh
[root@r9-systemd ~]# cat << 'EOF' > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
EOF
[root@r9-systemd ~]# cat << EOF > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
```
Стартуем юнит таймера, сервиса (*это важно, тк таймер будет отсчитывать время между запусками сервиса с момента как зафиксирует сервис в запущенном (active) состоянии, поэтому первый раз зпустить сервис нужно вручную*), ждем и проверяем журнал
```
[root@r9-systemd ~]# systemctl start watchlog.timer
[root@r9-systemd ~]# systemctl start watchlog.service
```
Ждем более 30 секунд и проверяем
```
[root@r9-systemd ~]# tail -f /var/log/messages
...
Apr  4 16:49:29 rocky9-box systemd[1]: Starting My watchlog service...
Apr  4 16:49:29 rocky9-box root[14812]: Tue Apr  4 16:49:29 MSK 2023: I found the word, Master!
Apr  4 16:49:29 rocky9-box systemd[1]: watchlog.service: Deactivated successfully.
Apr  4 16:49:29 rocky9-box systemd[1]: Finished My watchlog service.
Apr  4 16:50:00 rocky9-box systemd[1]: Starting My watchlog service...
Apr  4 16:50:00 rocky9-box root[14822]: Tue Apr  4 16:50:00 MSK 2023: I found the word, Master!
Apr  4 16:50:00 rocky9-box systemd[1]: watchlog.service: Deactivated successfully.
Apr  4 16:50:00 rocky9-box systemd[1]: Finished My watchlog service.
```
## Замена init-скрипта на unit-файл
В репозитории EPEL rhel9-based дистрибутивов нет требуемого пакета `spawn-fcgi`, поэтому для его установки настроим EPEL rhel8-based.
```
[root@r9-systemd ~]# grep -B 10 'gpgkey' -m 1 /etc/yum.repos.d/epel.repo > /etc/yum.repos.d/epel8.repo
[root@r9-systemd ~]# sed -ie 's/$releasever/8/g; s/\[epel\]/\[epel8\]/; s/enabled=1/enabled=0/' /etc/yum.repos.d/epel8.repo
[root@r9-systemd ~]# rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
[root@r9-systemd ~]# dnf -y install --enablerepo=epel8 spawn-fcgi php php-cli mod_fcgid httpd
```
Раскомментируем строки с переменными в `/etc/sysconfig/spawn-fcgi` и создадим unit-файл `/etc/systemd/system/spawn-fcgi.service`, помеcтив в него следующие строки:
```
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```
Проверим работоспособность
```
[root@r9-systemd ~]# systemctl start spawn-fcgi
[root@r9-systemd ~]# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor p>
     Active: active (running) since Tue 2023-04-04 21:55:26 MSK; 7s ago
   Main PID: 47285 (php-cgi)
      Tasks: 33 (limit: 4600)
     Memory: 16.9M
...
```
## Дополнить Unit-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигурациями
В `/usr/lib/systemd/system/httpd.service` зададим параметр для указания файлов окружения `EnvironmentFile=/etc/sysconfig/httpd-%I` 
```
sed -i 's$Environment=LANG=C$Environment=LANG=C\nEnvironmentFile=/etc/sysconfig/httpd-%I$' /usr/lib/systemd/system/httpd.service
```
Создадим сами файлы
```
[root@r9-systemd ~]# echo "OPTIONS=-f conf/first.conf" > /etc/sysconfig/httpd-first
[root@r9-systemd ~]# echo "OPTIONS=-f conf/second.conf" > /etc/sysconfig/httpd-second
```
Создадим файлы конфигурации с разными портами прослушивания
```
[root@r9-systemd ~]# cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
[root@r9-systemd ~]# cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
[root@r9-systemd ~]# sed -i 's%Listen 80%PidFile /var/run/httpd-first.pid\nListen 80%' /etc/httpd/conf/first.conf
[root@r9-systemd ~]# sed -i 's%Listen 80%PidFile /var/run/httpd-second.pid\nListen 8080%' /etc/httpd/conf/second.conf
```
Запустим инстансы и проверим, что указанные в конфигурациях порты прослушиваются процессами `httpd`
```
[root@r9-systemd ~]# systemctl start httpd@first
[root@r9-systemd ~]# systemctl start httpd@second
[root@r9-systemd ~]# ss -tulpn | grep httpd
tcp   LISTEN 0      511                *:8080            *:*    users:(("httpd",pid=47846,fd=4),("httpd",pid=47845,fd=4),("httpd",pid=47844,fd=4),("httpd",pid=47843,fd=4),("httpd",pid=47841,fd=4))
tcp   LISTEN 0      511                *:80              *:*    users:(("httpd",pid=47623,fd=4),("httpd",pid=47622,fd=4),("httpd",pid=47621,fd=4),("httpd",pid=47620,fd=4),("httpd",pid=47618,fd=4))
```
Все корректно работает.
**PROFIT!!!**

# Управление пакетами и дистрибьюция софта.
*Представленный в репозитории Vagrantfile разворачивает уже настроенную систему, шаги по достижению требуемой конфигурации описаны ниже и прописаны в скрипте `setup.sh`*

Установим необходимые для работы пакеты
```
[root@r9-rpm ~]# dnf install -y --enablerepo=devel redhat-lsb-core wget rpmdevtools rpm-build createrepo dnf-utils gcc
```
Загрузим srpm-пакет из оф. репозитория NGINX
```
[root@r9-rpm ~]# wget https://nginx.org/packages/rhel/9/SRPMS/nginx-1.22.1-1.el9.ngx.src.rpm
[root@r9-rpm ~]# rpm -i nginx-1.22.1-1.el9.ngx.src.rpm
```
Скачаем и разархивируем пакет исходников OpenSSL
```
[root@r9-rpm ~]# wget https://www.openssl.org/source/openssl-3.1.0.tar.gz
[root@r9-rpm ~]# tar -xf openssl-3.1.0.tar.gz
```
Установим все зависимости для сборки NGINX
```
[root@r9-rpm ~]# yum-builddep -y rpmbuild/SPECS/nginx.spec
```
Подредактируем файл spec
```
sed -i 's%--with-debug%--with-openssl=/root/openssl-3.1.0%' rpmbuild/SPECS/nginx.spec
```
Соберем RPM-пакет для NGINX с поддержкой OpenSSL
```
[root@r9-rpm ~]# rpmbuild -bb rpmbuild/SPECS/nginx.spec
[root@r9-rpm ~]# ll rpmbuild/RPMS/x86_64/
total 4172
-rw-r--r--. 1 root root 2517496 Mar 27 14:27 nginx-1.22.1-1.el9.ngx.x86_64.rpm
-rw-r--r--. 1 root root 1749982 Mar 27 14:27 nginx-debuginfo-1.22.1-1.el9.ngx.x86_64.rpm
```
Пакет успешно собрался, можно устанавливать и проверять
```
[root@r9-rpm ~]# dnf localinstall -y ./rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el9.ngx.x86_64.rpm
[root@r9-rpm ~]# systemctl start nginx
[root@r9-rpm ~]# systemctl status nginx
● nginx.service - nginx - high performance web server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor pr>
     Active: active (running) since Mon 2023-03-27 17:25:00 MSK; 5s ago
...
```
Сервис успешно установлен и запущен, тепeрь создадим собственный репозиторий на базе NGINX для собранного пакета NGINX плюс добавим еще один RPM
```
[root@r9-rpm ~]# mkdir /usr/share/nginx/html/repo
[root@r9-rpm ~]# cp rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el9.ngx.x86_64.rpm  /usr/share/nginx/html/repo/
[root@r9-rpm ~]# wget https://downloads.percona.com/downloads/percona-distribution-mysql-ps/percona-distribution-mysql-ps-8.0.32/binary/redhat/9/x86_64/percona-orchestrator-3.2.6-8.el9.x86_64.rpm -O /usr/share/nginx/html/repo/percona-orchestrator-3.2.6-8.el9.x86_64.rpm
```
Инициализируем репозиторий
```
[root@r9-rpm ~]# createrepo /usr/share/nginx/html/repo
Directory walk started
Directory walk done - 2 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Preparing sqlite DBs
Pool started (with 5 workers)
Pool finished
```
Настроим NGINX, проверим корректность конфига и перезапустим сервис
```
[root@r9-rpm ~]# sed -i '/index  index.html index.htm;/a\       \ autoindex  on;'  /etc/nginx/conf.d/default.conf
[root@r9-rpm ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@r9-rpm ~]# nginx -s reload
```
Проверим, что NGINX корректно отдает страничку репозитория
```
[root@r9-rpm ~]# curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          27-Mar-2023 14:58                   -
<a href="nginx-1.22.1-1.el9.ngx.x86_64.rpm">nginx-1.22.1-1.el9.ngx.x86_64.rpm</a>                  27-Mar-2023 14:30             2517496
<a href="percona-orchestrator-3.2.6-8.el9.x86_64.rpm">percona-orchestrator-3.2.6-8.el9.x86_64.rpm</a>        15-Mar-2023 17:38             5068062
</pre><hr></body>
</html>
```
Добавим конфигурацию и протестируем репозиторий
```
[root@r9-rpm ~]# cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
[root@r9-rpm ~]# dnf repolist enabled | grep otus
otus            otus-linux
[root@r9-rpm ~]# dnf list | grep otus
otus-linux                                      215 kB/s | 2.8 kB     00:00
nginx.x86_64                                                                             1:1.22.1-1.el9.ngx                   otus
percona-orchestrator.x86_64                                                              2:3.2.6-8.el9                        otus
[root@r9-rpm ~]# dnf install percona-orchestrator.x86_64 -y
Last metadata expiration check: 0:01:21 ago on Mon Mar 27 23:35:52 2023.
Dependencies resolved.
===============================================================================================================
 Package                           Architecture        Version                    Repository              Size
===============================================================================================================
Installing:
 percona-orchestrator              x86_64              2:3.2.6-8.el9              otus                   4.8 M
...
```
Пакет успешно установлен из локального репозитория. **PROFIT!**
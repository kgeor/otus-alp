# Docker
Задание:
1. Написать Dockerfile на базе apache/nginx который будет отдавать две статичные web-страницы
на разных портах. Например, 80 и 3000.
2. Пробросить эти порты на хост машину. Обе страницы должны быть доступны по адресам
localhost:80 и localhost:3000
3. Добавить 2 тома. Один для логов веб-сервера, другой для web-страниц.
## Выполнение
На развернутой ВМ Docker уже установлен, поэтому сразу выполним сборку нового образа с NGINX из Dockerfile
```
[vagrant@rocky9-docker ~]$ cd /vagrant/
[vagrant@rocky9-docker vagrant]$ docker build -t rocky-nginx .
[+] Building 55.3s (12/12) FINISHED
...
```
Создадим и запустим новый контейнер из полученного образа
```
[vagrant@rocky9-docker vagrant]$ docker run -d -p 80:80 -p 3000:3000 rocky-nginx
772d39c4e0c2de3bab31e899506e94efb450ca22554cb61fa7ab10ea73847c56
```
Прроверим корректность созданных томов (VOLUME)
```
[root@rocky9-docker ~]# ls /var/lib/docker/volumes
61f57f67a2ecdaf67409acbc67c0ff71869aeccc4f1adb773f023d7ad6588636
b675b3d43768d084bb51d2d270ea16c26dcf3f495368ca28120ff97ae63c3697
backingFsBlockDev
metadata.db
[root@rocky9-docker ~]# ls /var/lib/docker/volumes/61f57f67a2ecdaf67409acbc67c0ff71869aeccc4f1adb773f023d7ad6588636/_data/
access.log  error.log
[root@rocky9-docker ~]# ls /var/lib/docker/volumes/b675b3d43768d084bb51d2d270ea16c26dcf3f495368ca28120ff97ae63c3697/_data/
404.html  icons       nginx-logo.png  site1  system_noindex_logo.png
50x.html  index.html  poweredby.png   site2
```
Проверим, что NGINX правильно отдает страницы по разным портам
```
[vagrant@rocky9-docker vagrant]$ curl localhost:80
<!DOCTYPE html>
<html>
        <head>
                <title>page1</title>
        </head>
        <body>
                <h1></h1>
                <p>available on 80 port</p>
        </body>
</html>[vagrant@rocky9-docker vagrant]$ curl localhost:3000
<!DOCTYPE html>
<html>
        <head>
                <title>page2</title>
        </head>
        <body>
                <h1></h1>
                <p>available on 3000 port</p>
        </body>
</html>[vagrant@rocky9-docker vagrant]$
```
**PROFIT!**

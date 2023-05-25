# PAM.
## Настройка запрета для всех пользователей (кроме группы Admin) логина в выходные дни (Праздники не учитываются)
Создадим пользователей с одинаковым паролем
```
[vagrant@rocky9-pam ~]$ sudo -i
[root@rocky9-pam ~]# useradd otusadm && useradd otus
[root@rocky9-pam ~]# echo "Otus2023!" | passwd --stdin otusadm && echo "Otus2023!" | passwd --stdin otus
Changing password for user otusadm.
passwd: all authentication tokens updated successfully.
Changing password for user otus.
passwd: all authentication tokens updated successfully.
```
Создадим группу admin и добавим пользователей vagrant,root и otusadm в нее.
```
[root@rocky9-pam ~]# groupadd -f admin
[root@rocky9-pam ~]# usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
```
Пробуем подключиться с хостовой ОС
```
[kgeor@rocky-ls lab15]$ ssh otus@192.168.56.15
otus@192.168.56.15's password:
Last login: Thu May 25 11:24:12 2023 from 192.168.56.1
[otus@rocky9-pam ~]$
logout
Connection to 192.168.56.15 closed.
[kgeor@rocky-ls lab15]$ ssh otusadm@192.168.56.15
otusadm@192.168.56.15's password:
Last login: Thu May 25 11:25:06 2023 from 192.168.56.1
[otusadm@rocky9-pam ~]$ whoami
otusadm
```
Проверим состав группы `admin`
```
[root@rocky9-pam ~]# cat /etc/group | grep ^admin
admin:x:1003:otusadm,root,vagrant
```
Для контроля доступа в выходные дни будем использовать модуль `pam_exec`, создадим для него файл скрипта /usr/local/bin/login.sh
```
cat << 'EOF' > /usr/local/bin/login.sh
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
EOF
[root@rocky9-pam ~]# chmod +x /usr/local/bin/login.sh
```
Укажем в файле /etc/pam.d/sshd обязательный модуль pam_exec
```
...
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/login.sh
...
```
Проверим работоспособность, выставим в системе дату так, чтобы она выпала на выходной
```
[root@rocky9-pam ~]# systemctl stop chronyd
[root@rocky9-pam ~]# systemctl stop --all vboxadd*
[root@rocky9-pam ~]# date -s "20 May 2023 13:00:00"
Sat May 20 13:00:00 MSK 2023
...
[kgeor@rocky-ls lab15]$ ssh otus@192.168.56.15
otus@192.168.56.15's password:
/usr/local/bin/login.sh failed: exit code 1
Connection closed by 192.168.56.15 port 22
[kgeor@rocky-ls lab15]$ ssh otusadm@192.168.56.15
otusadm@192.168.56.15's password:
Last login: Thu May 25 11:25:12 2023 from 192.168.56.1
[otusadm@rocky9-pam ~]$ date
Sat May 20 13:05:18 MSK 2023
```
## Разрешить определенному пользователю работать с Docker и рестартить Docker сервис
Установим Docker
```
[root@rocky9-pam ~]# dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
...
```
Добавим пользователя `otus` в группу docker, чтобы дать возможность работать с Docker
```
[root@rocky9-pam ~]# usermod -aG docker otus
```
Теперь сделаем возможным рестарт докер сервиса от этого пользователя добавлением правила PolKit
```
cat > /etc/polkit-1/rules.d/10-docker.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "docker.service" &&
        subject.user == "otus") {
        return polkit.Result.YES;
    }
})
EOF
```
Проверим работоспособность под пользователем otus
```
[otus@rocky9-pam ~]$ whoami
otus
[otus@rocky9-pam ~]$ systemctl status docker
○ docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
     Active: inactive (dead)
TriggeredBy: ○ docker.socket
       Docs: https://docs.docker.com
[otus@rocky9-pam ~]$ systemctl start docker
[otus@rocky9-pam ~]$ systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
     Active: active (running) since Thu 2023-05-25 13:47:54 MSK; 2s ago
...
```
**PROFIT!**
# Резервное копирование
Задание:
1) Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client.
2) Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:
- директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;
- репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;
- имя бекапа должно содержать информацию о времени снятия бекапа;
- глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
- резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
- написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;
- настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.
3) Запустите стенд на 30 минут.
4) Убедитесь что резервные копии снимаются.
5) Остановите бекап, удалите (или переместите) директорию /etc и восстановите ее из бекапа.
## Создание бэкапа вручную
На клиенте и сервере уже  установлен `borgbackup`, добавлен ключ клиента
Зайдем на клиент `vagrant ssh borg-client`
Инициализируем репозиторий (здесь и далее все делается под пользователем `root`)
```
[root@rocky9-borg-client ~]# borg init --encryption=repokey borg@10.0.5.10:/var/backup/borg_repo
The authenticity of host '10.0.5.10 (10.0.5.10)' can't be established.
ED25519 key fingerprint is SHA256:7NPvz5lYyqfI0HM1Mo1FZDOKLaIsf4RZi9iPa6sNPb0.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Remote: Warning: Permanently added '10.0.5.10' (ED25519) to the list of known hosts.
Enter new passphrase:
otus
...
```
Создадим первый бэкап
```
[root@rocky9-borg-client ~]# borg create --stats --list borg@10.0.5.10:/var/backup/borg_repo::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
...
------------------------------------------------------------------------------
Repository: ssh://borg@10.0.5.10/var/backup/borg_repo
Archive name: etc-2023-08-23_22:46:41
Archive fingerprint: 0ec359e887d35a74879389e1d20bbf1cb292ac77d736317964817fd7067e528d
Time (start): Wed, 2023-08-23 22:46:49
Time (end):   Wed, 2023-08-23 22:46:50
Duration: 1.09 seconds
Number of files: 455
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               20.10 MB              6.93 MB              6.93 MB
All archives:               20.10 MB              6.93 MB              6.98 MB

                       Unique chunks         Total chunks
Chunk index:                     448                  455
------------------------------------------------------------------------------
```
Проверим, что сейчас лежит в репозитории
``` 
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
etc-2023-08-23_22:46:41              Wed, 2023-08-23 22:46:49 [0ec359e887d35a74879389e1d20bbf1cb292ac77d736317964817fd7067e528d]

```
Детальнее выведем содержимое бэкапа
```
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo::etc-2023-08-23_22:46:41
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
drwxr-xr-x root   root          0 Wed, 2023-08-23 22:44:08 etc
...
```
Вывод полностью соответствует дереву директорий /etc, попробуем восстановить один из файлов
```
[root@rocky9-borg-client ~]# borg extract borg@10.0.5.10:/var/backup/borg_repo::etc-2023-08-23_22:46:41 /etc/hostname
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
[root@rocky9-borg-client ~]# cat ~/etc/hostname
rocky9-borg-client
```
Файл успешно экспортирован из бэкапа, теперь остается автоматизировать процесс. Создадим службу systemd и таймер для нее.
```
cat > /etc/systemd/system/borg-backup.service << 'EOF'
[Unit]
Description=Borg Backup

[Service]
Type=oneshot

# Парольная фраза
Environment="BORG_PASSPHRASE=otus"
# Репозиторий
Environment="REPO=borg@10.0.5.10:/var/backup/borg_repo"
# Что бэкапим
Environment="BACKUP_TARGET=/etc"

# Создание бэкапа
ExecStart=/usr/bin/borg create --stats \
${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} \
${BACKUP_TARGET}

# Проверка бэкапа
ExecStart=/usr/bin/borg check ${REPO}

# Очистка старых бэкапов
ExecStart=/usr/bin/borg prune --keep-daily 90 \
--keep-monthly 12 --keep-yearly 1 ${REPO}
EOF

cat > /etc/systemd/system/borg-backup.timer << 'EOF'
[Unit]
Description=Borg Backup

[Timer]
OnBootSec=5m
OnUnitActiveSec=5m

[Install]
WantedBy=timers.target
EOF
```
Запустим сервис и проверим работоспособность, а также логирование (стандартное для сервисов systemd)
```
[root@rocky9-borg-client ~]# systemctl daemon-reload
[root@rocky9-borg-client ~]# systemctl enable --now borg-backup.timer
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
etc-2023-08-23_22:46:41              Wed, 2023-08-23 22:46:49 [0ec359e887d35a74879389e1d20bbf1cb292ac77d736317964817fd7067e528d]
etc-2023-08-23_22:53:00              Wed, 2023-08-23 22:53:01 [c2bffcc28c694fcfa96532a412e1ccb4002230edfea34258d103857baa4f6a22]
[root@rocky9-borg-client ~]# less +G /var/log/messages
...
Aug 23 22:53:00 rocky9-box systemd[1]: Starting Borg Backup...
Aug 23 22:53:02 rocky9-box borg[50606]: ----------------------------------------------
--------------------------------
Aug 23 22:53:02 rocky9-box borg[50606]: Repository: ssh://borg@10.0.5.10/var/backup/bo
rg_repo
Aug 23 22:53:02 rocky9-box borg[50606]: Archive name: etc-2023-08-23_22:53:00
Aug 23 22:53:02 rocky9-box borg[50606]: Archive fingerprint: c2bffcc28c694fcfa96532a41
2e1ccb4002230edfea34258d103857baa4f6a22
Aug 23 22:53:02 rocky9-box borg[50606]: Time (start): Wed, 2023-08-23 22:53:01
Aug 23 22:53:02 rocky9-box borg[50606]: Time (end):   Wed, 2023-08-23 22:53:01
Aug 23 22:53:02 rocky9-box borg[50606]: Duration: 0.14 seconds
Aug 23 22:53:02 rocky9-box borg[50606]: Number of files: 457
Aug 23 22:53:02 rocky9-box borg[50606]: Utilization of max. archive size: 0%
Aug 23 22:53:02 rocky9-box borg[50606]: ------------------------------------------------------------------------------
Aug 23 22:53:02 rocky9-box borg[50606]:                       Original size      Compressed size    Deduplicated size
Aug 23 22:53:02 rocky9-box borg[50606]: This archive:               20.10 MB              6.93 MB              1.28 kB
Aug 23 22:53:02 rocky9-box borg[50606]: All archives:               40.20 MB             13.87 MB              7.02 MB
Aug 23 22:53:02 rocky9-box borg[50606]:                       Unique chunks         Total chunks
Aug 23 22:53:02 rocky9-box borg[50606]: Chunk index:                     452                  912
Aug 23 22:53:02 rocky9-box borg[50606]: ------------------------------------------------------------------------------
Aug 23 22:53:03 rocky9-box systemd[1]: borg-backup.service: Deactivated successfully.
Aug 23 22:53:03 rocky9-box systemd[1]: Finished Borg Backup.
Aug 23 22:53:03 rocky9-box systemd[1]: borg-backup.service: Consumed 1.194s CPU time.
```
Директория бэкапится, лог пишется.

Восстановим директорию /etc целиком. Поскольку если удалить/переместить /etc полностью, то не будет работать ssh (т.к. невозможно сопоставить uid пользователю), то оставим файл passwd.
```
[root@rocky9-borg-client ~]# systemctl stop borg-backup.timer
[root@rocky9-borg-client ~]# mkdir /opt/etc && cd /etc
[root@rocky9-borg-client etc]# mv $(ls --ignore=passwd /etc) /opt/etc/
[root@rocky9-borg-client etc]# cd ~ && borg extract borg@10.0.5.10:/var/backup/borg_repo::etc-2023-08-23_22:46:41
[root@rocky9-borg-client ~]# rm -rf /etc && mv etc/ /
```
Директория /etc успешно восстановлена.

 **PROFIT!!!**

# Резервное копирование
## Создание бэкапа вручную
На клиенте и сервере уже  установлен `borgbackup`, добавлен ключ клиента

Инициализируем репозиторий
```
[root@rocky9-borg-client ~]# borg init --encryption=repokey borg@10.0.5.10:/var/backup/borg_repo
Enter new passphrase:
...
```
Создадим первый бэкап
```
[root@rocky9-borg-client ~]# borg create --stats --list borg@10.0.5.10:/var/backup/borg_repo::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
...
Repository: ssh://borg@10.0.5.10/var/backup/borg_repo
Archive name: etc-2023-06-29_16:42:50
Archive fingerprint: 6d3efc6246aaa199dbc529d62e955f01d1a82c3696008dbe101ace58d74962c7
Time (start): Thu, 2023-06-29 16:42:54
Time (end):   Thu, 2023-06-29 16:42:55
Duration: 1.01 seconds
Number of files: 455
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               20.10 MB              6.93 MB              6.93 MB
All archives:               20.10 MB              6.93 MB              6.98 MB

                       Unique chunks         Total chunks
Chunk index:                     447                  454
------------------------------------------------------------------------------
```
Проверим, что сейчас лежит в репозитории
```
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo     
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
etc-2023-06-29_16:42:50              Thu, 2023-06-29 16:42:54 [6d3efc6246aaa199dbc529d62e955f01d1a82c3696008dbe101ace58d74962c7]
```
Детальнее выведем содержимое бэкапа
```
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo::etc-2023-06-29_16:42:50
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
drwxr-xr-x root   root          0 Thu, 2023-06-29 16:29:27 etc
...
```
Вывод полностью соответствует дереву директорий /etc, попробуем восстановить один из файлов
```
[root@rocky9-borg-client ~]# borg extract borg@10.0.5.10:/var/backup/borg_repo::etc-2023-06-29_16:42:50 /etc/hostname
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
[root@rocky9-borg-client ~]# cat ~/etc/hostname
rocky9-borg-client
```
Файл успешно экспортирован из бэкапа, теперь остается автоматизировать процесс. Создадим службу systemd  и таймер для нее.
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
ExecStart=/usr/bin/borg prune --keep-hourly 10 --keep-daily 90 \
--keep-monthly 12 --keep-yearly 1 ${REPO}
EOF

cat > /etc/systemd/system/borg-backup.timer << 'EOF'
[Unit]
Description=Borg Backup

[Timer]
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF
```
Запусти сервис и проверим работоспособность, а также логирование (стандартное для сервисов systemd)
```
[root@rocky9-borg-client ~]# systemctl daemon-reload
[root@rocky9-borg-client ~]# systemctl enable borg-backup.timer
[root@rocky9-borg-client ~]# borg list borg@10.0.5.10:/var/backup/borg_repo
Enter passphrase for key ssh://borg@10.0.5.10/var/backup/borg_repo:
etc-2023-06-29_16:42:50              Thu, 2023-06-29 16:42:54 [6d3efc6246aaa199dbc529d62e955f01d1a82c3696008dbe101ace58d74962c7]
etc-2023-06-29_17:19:21              Thu, 2023-06-29 17:19:22 [077054541d398282fd51a9d2cc7e4e86eac01203bcb699dbafc639aff7321ca4]
[root@rocky9-borg-client ~]# less +G /var/log/messages
...
Jun 29 17:19:21 rocky9-box systemd[1]: Starting Borg Backup...
Jun 29 17:19:22 rocky9-box borg[51215]: ----------------------------------------
--------------------------------------
Jun 29 17:19:22 rocky9-box borg[51215]: Repository: ssh://borg@10.0.5.10/var/bac
kup/borg_repo
Jun 29 17:19:22 rocky9-box borg[51215]: Archive name: etc-2023-06-29_17:19:21
Jun 29 17:19:22 rocky9-box borg[51215]: Archive fingerprint: 077054541d398282fd5
1a9d2cc7e4e86eac01203bcb699dbafc639aff7321ca4
Jun 29 17:19:22 rocky9-box borg[51215]: Time (start): Thu, 2023-06-29 17:19:22
Jun 29 17:19:22 rocky9-box borg[51215]: Time (end):   Thu, 2023-06-29 17:19:22
Jun 29 17:19:22 rocky9-box borg[51215]: Duration: 0.11 seconds
Jun 29 17:19:22 rocky9-box borg[51215]: Number of files: 457
Jun 29 17:19:22 rocky9-box borg[51215]: Utilization of max. archive size: 0%
Jun 29 17:19:22 rocky9-box borg[51215]: ----------------------------------------
--------------------------------------
Jun 29 17:19:22 rocky9-box borg[51215]:                       Original size
 Compressed size    Deduplicated size
Jun 29 17:19:22 rocky9-box borg[51215]: This archive:               20.10 MB
          6.93 MB                620 B
Jun 29 17:19:22 rocky9-box borg[51215]: All archives:               60.31 MB
         20.80 MB              7.02 MB
Jun 29 17:19:22 rocky9-box borg[51215]:                       Unique chunks         Total chunks
Jun 29 17:19:22 rocky9-box borg[51215]: Chunk index:                     452                 1366
Jun 29 17:19:22 rocky9-box borg[51215]: ------------------------------------------------------------------------------
Jun 29 17:19:25 rocky9-box systemd[1]: borg-backup.service: Deactivated successfully.
Jun 29 17:19:25 rocky9-box systemd[1]: Finished Borg Backup.
Jun 29 17:19:25 rocky9-box systemd[1]: borg-backup.service: Consumed 1.184s CPU time.
```
Директория бэкапится, лог пишется. **PROFIT!!!**
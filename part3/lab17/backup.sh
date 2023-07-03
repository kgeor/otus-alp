#!/bin/bash
BORG_SERVER="borg@10.100.0.10"
PATH="/var/backup"
borg init --encryption=repokey borg@10.100.0.10:repo
borg create --stats --list borg@10.100.0.10:/var/backup::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
borg list borg@10.100.0.10:/var/backup
cat > /etc/systemd/system/borg-backup.service << 'EOF'
[Unit]
Description=Borg Backup

[Service]
Type=oneshot

# Парольная фраза
Environment="BORG_PASSPHRASE=Otus1234"
# Репозиторий
Environment=REPO=borg@10.100.0.10:/var/backup/
# Что бэкапим
Environment=BACKUP_TARGET=/etc

# Создание бэкапа
ExecStart=/bin/borg create \
    --stats                \
    ${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}

# Проверка бэкапа
ExecStart=/bin/borg check ${REPO}

# Очистка старых бэкапов
ExecStart=/bin/borg prune \
    --keep-daily  90      \
    --keep-monthly 12     \
    --keep-yearly  1       \
    ${REPO}
EOF

cat > /etc/systemd/system/borg-backup.timer << 'EOF'
[Unit]
Description=Borg Backup

[Timer]
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable borg-backup.timer
systemctl start borg-backup.timer

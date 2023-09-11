# PostgreSQL
## Репликация
На развернутых ВМ уже установлен postgresql, можно сразу приступать к настройке репликации.

С хостовой ОС запустим выполнение ansible плейбука
```
ansible-playbook -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -l all ansible/playbook.yml -t replication -e '{"ansible_host_key_checking": false,}'
```
Далее создадим новую БД на `node1`
```
[vagrant@node1 ~]$ sudo -u postgres psql
...
postgres=# CREATE DATABASE otus_test;
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 otus_test | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

```
Проверим, что созданная БД также появилась и на `node2`
```
[vagrant@node2 ~]$ sudo -u postgres psql
...
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 otus_test | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)
```
БД появилась на сервере-реплике, репликация работает как ожидается.

## Бэкап
С хостовой ОС запустим выполнение ansible плейбука
```
ansible-playbook -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -l all ansible/playbook.yml -t backup -e '{"ansible_host_key_checking": false,}'
```
Зайдем на хост `barman` и выполним лонастройку и проверку резервного копирования
```
[barman@barman ~]$ barman switch-wal node1
The WAL file 000000010000000000000003 has been closed on server 'node1'
[barman@barman ~]$ barman cron
Starting WAL archiving for server node1
[barman@barman ~]$ barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        backup minimum size: OK (0 B)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
[barman@barman ~]$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20230908T191648
Backup start at LSN: 0/4000060 (000000010000000000000004, 00000060)
Starting backup copy via pg_basebackup for 20230908T191648
Copy done (time: 9 seconds)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
        000000010000000000000003 from server node1 has been removed
Backup size: 41.9 MiB
Backup end at LSN: 0/6000060 (000000010000000000000006, 00000060)
Backup completed (start time: 2023-09-08 19:16:48.642846, elapsed time: 17 seconds)
```
Бэкап успешно снят, попробуем восстановиться из него, предварительно удалив БД с `node1`

```
[vagrant@node1 ~]$ sudo -u postgres psql
...
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 otus_test | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(5 rows)
```
Удалим созданные ранее базы
```
postgres=# DROP DATABASE otus;
DROP DATABASE
postgres=# DROP DATABASE otus_test;
DROP DATABASE
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(3 rows)
```
Остановим сервис БД и перейдем на `barman` для восстановления
```
[vagrant@node1 ~]$ sudo systemctl stop postgresql-14
...
[barman@barman ~]$ barman list-backup node1
node1 20230908T191648 - Fri Sep  8 13:16:57 2023 - Size: 41.9 MiB - WAL Size: 0 B
[barman@barman ~]$ barman recover node1 20230908T191648 var/lib/pgsql/14/data/ --remote-ssh-comman "ssh postgres@192.168.57.11"
...
```
Снова вернемся на `node1`, запустим postgresql и проверим наличие баз
```
[vagrant@node1 ~]$ sudo systemctl start postgresql-14
[vagrant@node1 ~]$ sudo -u postgres psql
...
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 otus_test | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(5 rows)
```
Удаленные БД вновь появились. It's seems tobe OK.
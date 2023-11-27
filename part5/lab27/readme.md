# MySQL
Задание:
1) В материалах приложены ссылки на вагрант для репликации и дамп базы bet.dmp
2) Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:
| bookmaker |
| competition |
| market |
| odds |
| outcome |
3) Настроить GTID репликацию
## Выполнение
После развертывания мы получаем ВМ, на которой развернуты контейнеры с пустым MySQL сервером. 

Создадим на мастере пустую БД bet и пользователя repl.
```
[vagrant@docker-host files]$ docker exec -ti mysql8master sh -c 'exec mysql -u root -p'
...
mysql> CREATE DATABASE bet;
mysql> CREATE USER repl@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'Slave#2023';
Query OK, 0 rows affected (0.06 sec)
mysql> GRANT REPLICATION SLAVE ON *.* TO repl@'%';
Query OK, 0 rows affected (0.09 sec)
mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.02 sec)
```
Далее, все так же на мастере, восстановим БД bet из дампа, проверим
```
[vagrant@docker-host files]$ docker exec -ti mysql8master sh -c 'exec mysql -u root -p -D bet < /mnt/bet.dmp'
[vagrant@docker-host files]$ docker exec -ti mysql8master sh -c 'exec mysql -u root -p'
...
mysql> use bet;
...
mysql> show tables;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)
```
Теперь настроим сервер-реплику, проверим синхронизацию с мастером
```
[vagrant@docker-host files]$ docker exec -ti mysql8slave sh -c 'exec mysql -u root -p'
mysql> STOP SLAVE;
Query OK, 0 rows affected, 2 warnings (0.01 sec)

mysql> CHANGE MASTER TO MASTER_HOST='mysql8master', MASTER_USER='repl', MASTER_PASSWORD='Slave#2023', MASTER_AUTO_POSITION = 1, GET_MASTER_PUBLIC_KEY = 1;
Query OK, 0 rows affected, 8 warnings (0.25 sec)

mysql> START SLAVE;
Query OK, 0 rows affected, 1 warning (0.12 sec)

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| bet                |
| information_schema |
| mysql              |
| performance_schema |
| super_db           |
| sys                |
+--------------------+
```
БД bet появилась на реплике, дополнительно в другой БД создадим таблицу и заполним данными, потом проверим на реплике
```
[vagrant@docker-host files]$ docker exec -ti mysql8master sh -c 'exec mysql -u root -p'
...
mysql> use super_db;
Database changed
mysql> create table test_tbl (id int, name_fld varchar(255), PRIMARY KEY (id));
Query OK, 0 rows affected (0.23 sec)

mysql> insert into test_tbl values (2,'super'),(3,'hyper'),(4,'lower');
Query OK, 3 rows affected (0.03 sec)
Records: 3  Duplicates: 0  Warnings: 0

[vagrant@docker-host files]$ docker exec -ti mysql8slave sh -c 'exec mysql -u root -p'
mysql> select * from super_db.test_tbl;
+----+----------+
| id | name_fld |
+----+----------+
|  2 | super    |
|  3 | hyper    |
|  4 | lower    |
+----+----------+
3 rows in set (0.00 sec)
```
It's work.

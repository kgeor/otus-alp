#!/bin/bash
if [ ! -f ./.env ]; then
    echo ".env file not found, script shutting down!"
    echo $#
    exit
fi
source .env
exec 2> ./init_db_err.log
if [[ $# -eq 0 ]]; then
echo "Provisioning both nodes (cold start)"
until docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e ";"; do
    echo "Can't connect to db1, retrying..."
    sleep 10
done
for node in db1 db2
do
    if [[ $(docker exec $node mysql -u root -p$DB_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" | grep Slave_IO_State) ]]; then
        echo "Node $node seems to have already been provisioned. Exiting"
        exit
    fi
done
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER repl@'%' IDENTIFIED BY 'repl#2023'"
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT REPLICATION SLAVE ON *.* TO repl@'%'"
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES"
# docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "SET @@GLOBAL.read_only = ON"
echo "Dumping from db1..."
mysqldump --all-databases --triggers --routines --events --single-transaction --ignore-table=mysql.innodb_index_stats --ignore-table=mysql.innodb_table_stats\
 --ignore-table=mysql.server_cost --ignore-table=mysql.engine_cost --host=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db1)\
 --port=3306 --user=root --password=$DB_ROOT_PASSWORD > init_dump.sql
# docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "SET @@GLOBAL.read_only = OFF"
until docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e ";" ; do
    echo "Can't connect to db2, retrying..."
    sleep 3
done
echo "Uploading dump to db2..."
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "RESET MASTER" #
mysql -h $(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db2)\
 -u root -p$DB_ROOT_PASSWORD < init_dump.sql
#docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "SET @@GLOBAL.read_only = OFF;" > /dev/null
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "STOP SLAVE"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "RESET SLAVE"
# exit
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CHANGE MASTER TO
MASTER_HOST = 'db1',
MASTER_PORT = 3306,
MASTER_USER = 'repl',
MASTER_PASSWORD = 'repl#2023',
MASTER_AUTO_POSITION = 1,
GET_MASTER_PUBLIC_KEY = 1"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "START SLAVE"
echo "db2"
until docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" | grep "read all"; do
    echo "Replica is still syncronizing, waiting..."
    sleep 3
done
# docker exec -i db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER repl@'%' IDENTIFIED BY 'repl#2023';" > /dev/null
# docker exec -i db2 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT REPLICATION SLAVE ON *.* TO repl@'%';" > /dev/null
# docker exec -i db2 mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;" > /dev/null
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "STOP SLAVE"
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "RESET SLAVE"
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "CHANGE MASTER TO
MASTER_HOST = 'db2',
MASTER_PORT = 3306,
MASTER_USER = 'repl',
MASTER_PASSWORD = 'repl#2023',
MASTER_AUTO_POSITION = 1,
GET_MASTER_PUBLIC_KEY = 1"
docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "START SLAVE"
echo "db1"
until docker exec db1 mysql -u root -p$DB_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" | grep "read all"; do
    echo "Replica is still syncronizing, waiting..."
    sleep 3
done
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER 'exporter'@'%' IDENTIFIED BY 'export_metr' WITH MAX_USER_CONNECTIONS 2"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%'"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER 'haproxy_check'@'%' IDENTIFIED WITH mysql_native_password"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD'"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER 'bkp'@'%' IDENTIFIED WITH mysql_native_password BY 'bkp#2023' WITH MAX_USER_CONNECTIONS 2"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON $DB_NAME.* TO 'bkp'@'%'"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT PROCESS ON *.* TO 'bkp'@'%'"
docker exec db2 mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES"
exit
fi
if [[ $# -eq 1 ]]; then
echo "Provisioning $1 node"
until docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e ";"; do
    echo "Can't connect to $1, retrying..."
    sleep 10
done
if [[ $(docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" | grep Slave_IO_State) ]]; then
    echo "Node $1 seems to have already been provisioned. Exiting"
    exit
fi
[[ $1 == "db1" ]] && master="db2" || master="db1"
docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "STOP SLAVE"
# docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "RESET SLAVE"
# docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "RESET MASTER"
# docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH TABLES WITH READ LOCK"
echo "Dumping from $master..."
mysqldump --all-databases --triggers --routines --events --single-transaction --ignore-table=mysql.innodb_index_stats --ignore-table=mysql.innodb_table_stats\
 --ignore-table=mysql.server_cost --ignore-table=mysql.engine_cost --host=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $master)\
 --port=3306 --user=root --password=$DB_ROOT_PASSWORD > init_dump.sql
# docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "UNLOCK TABLES"
docker exec -i haproxy bash -c "echo 'disable server mysql_back/$1' | socat unix-connect:/var/lib/haproxy/stats stdio"
echo "Uploading dump to $1..."
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "RESET MASTER"
mysql -h $(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $1)\
 -u root -p$DB_ROOT_PASSWORD -f < init_dump.sql
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "STOP SLAVE"
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "RESET SLAVE"
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "CHANGE MASTER TO
MASTER_HOST = '$master',
MASTER_PORT = 3306,
MASTER_USER = 'repl',
MASTER_PASSWORD = 'repl#2023',
MASTER_AUTO_POSITION = 1,
GET_MASTER_PUBLIC_KEY = 1"
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "START SLAVE"
until docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" | grep "read all"; do
    echo "Replica is still syncronizing, waiting..."
    sleep 3
done
#docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "RESET SLAVE"
docker exec $master mysql -u root -p$DB_ROOT_PASSWORD -e "START SLAVE"
docker exec $1 mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES"
docker exec -i haproxy bash -c "echo 'enable server mysql_back/$1' | socat unix-connect:/var/lib/haproxy/stats stdio"
fi

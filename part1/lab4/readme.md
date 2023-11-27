# ZFS
Задание:
1) Определить алгоритм с наилучшим сжатием.
- определить какие алгоритмы сжатия поддерживает zfs (gzip gzip-N, zle lzjb, lz4);
- создать 4 файловых системы на каждой применить свой алгоритм сжатия;
- Для сжатия использовать либо текстовый файл либо группу файлов: скачать файл “Война и мир” и расположить на файловой системе wget -O War_and_Peace.txt http://www.gutenberg.org/ebooks/2600.txt.utf-8, либо скачать файл ядра распаковать и расположить на файловой системе.
2) Определить настройки pool’a.
- загрузить архив с файлами локально https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg Распаковать.
- с помощью команды zfs import собрать pool ZFS;
командами zfs определить настройки:
- размер хранилища;
- тип pool;
- значение recordsize;
- какое сжатие используется;
- какая контрольная сумма используется.
3) файл с описанием настроек settings.
Найти сообщение от преподавателей.
- скопировать файл из удаленной директории. https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing
- Файл был получен командой zfs send otus/storage@task2 > otus_task2.file
- восстановить файл локально. zfs receive
- найти зашифрованное сообщение в файле secret_message
## Алгоритмы сжатия
*Работа проводилась на базе чистого образа Rocky Linux 9.1 с дефолтным ядром*
Создадим 4 пула zpool типа зеркало и назначим каждому свой алгоритм сжатия
```
[root@zfs-l4 ~]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   10G  0 disk
├─sda1   8:1    0  100M  0 part /boot/efi
├─sda2   8:2    0 1000M  0 part /boot
├─sda3   8:3    0    4M  0 part
├─sda4   8:4    0    1M  0 part
└─sda5   8:5    0  7.8G  0 part /
sdb      8:16   0  512M  0 disk
sdc      8:32   0  512M  0 disk
sdd      8:48   0  512M  0 disk
sde      8:64   0  512M  0 disk
sdf      8:80   0  512M  0 disk
sdg      8:96   0  512M  0 disk
sdh      8:112  0  512M  0 disk
sdi      8:128  0  512M  0 disk
[root@zfs-l4 ~]# zpool create otus1 mirror /dev/sdb /dev/sdc
[root@zfs-l4 ~]# zpool create otus2 mirror /dev/sdd /dev/sde
[root@zfs-l4 ~]# zpool create otus3 mirror /dev/sdf /dev/sdg
[root@zfs-l4 ~]# zpool create otus4 mirror /dev/sdh /dev/sdi
[root@zfs-l4 ~]# zfs set compression=lzjb otus1
[root@zfs-l4 ~]# zfs set compression=lz4 otus2
[root@zfs-l4 ~]# zfs set compression=gzip-9 otus3
[root@zfs-l4 ~]# zfs set compression=zle otus4
```
Посмотрим на эффективность сжатия данных в пулах
```
[root@zfs-l4 ~]# for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
--2023-03-21 16:49:12--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40912739 (39M) [text/plain]
Saving to: ‘/otus1/pg2600.converter.log’

pg2600.converter.lo 100%[===================>]  39.02M  1.14MB/s    in 35s
...
[root@zfs-l4 ~]# zfs list
NAME    USED  AVAIL     REFER  MOUNTPOINT
otus1  21.7M   330M     21.6M  /otus1
otus2  17.7M   334M     17.6M  /otus2
otus3  10.8M   341M     10.7M  /otus3
otus4  39.2M   313M     39.1M  /otus4
[root@zfs-l4 ~]# zfs get all | grep compressratio | grep -v ref
otus1  compressratio         1.81x                  -
otus2  compressratio         2.22x                  -
otus3  compressratio         3.65x                  -
otus4  compressratio         1.00x                  -
```
Алгоритм gzip-9, используемый в пуле otus3 самый эффективный по коэффициенту сжатия.
## Определение настроек пула
Скачаем архив с экспортированными файлами пула и импортируем в ОС
```
[root@zfs-l4 ~]# wget -O archive.tar.gz --no-check-certificate 'https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download'
...
2023-03-22 07:55:30 (1.10 MB/s) - ‘archive.tar.gz’ saved [7275140/7275140]

[root@zfs-l4 ~]# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
[root@zfs-l4 ~]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
[root@zfs-l4 ~]# zpool import -d zpoolexport/ otus
[root@zfs-l4 ~]# zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```
Определим параметры импортированного пула
```
[root@zfs-l4 ~]# zfs get all otus
NAME  PROPERTY              VALUE                  SOURCE
otus  type                  filesystem             -
otus  creation              Fri May 15  4:00 2020  -
otus  used                  2.04M                  -
otus  available             350M                   -
otus  referenced            24K                    -
otus  compressratio         1.00x                  -
otus  mounted               yes                    -
otus  quota                 none                   default
otus  reservation           none                   default
otus  recordsize            128K                   local
otus  mountpoint            /otus                  default
otus  sharenfs              off                    default
otus  checksum              sha256                 local
otus  compression           zle                    local
otus  atime                 on                     default
otus  devices               on                     default
otus  exec                  on                     default
otus  setuid                on                     default
otus  readonly              off                    default
otus  zoned                 off                    default
otus  snapdir               hidden                 default
otus  aclmode               discard                default
otus  aclinherit            restricted             default
otus  createtxg             1                      -
otus  canmount              on                     default
otus  xattr                 on                     default
otus  copies                1                      default
otus  version               5                      -
otus  utf8only              off                    -
otus  normalization         none                   -
otus  casesensitivity       sensitive              -
otus  vscan                 off                    default
otus  nbmand                off                    default
otus  sharesmb              off                    default
otus  refquota              none                   default
otus  refreservation        none                   default
otus  guid                  14592242904030363272   -
otus  primarycache          all                    default
otus  secondarycache        all                    default
otus  usedbysnapshots       0B                     -
otus  usedbydataset         24K                    -
otus  usedbychildren        2.01M                  -
otus  usedbyrefreservation  0B                     -
otus  logbias               latency                default
otus  objsetid              54                     -
otus  dedup                 off                    default
otus  mlslabel              none                   default
otus  sync                  standard               default
otus  dnodesize             legacy                 default
otus  refcompressratio      1.00x                  -
otus  written               24K                    -
otus  logicalused           1020K                  -
otus  logicalreferenced     12K                    -
otus  volmode               default                default
otus  filesystem_limit      none                   default
otus  snapshot_limit        none                   default
otus  filesystem_count      none                   default
otus  snapshot_count        none                   default
otus  snapdev               hidden                 default
otus  acltype               off                    default
otus  context               none                   default
otus  fscontext             none                   default
otus  defcontext            none                   default
otus  rootcontext           none                   default
otus  relatime              off                    default
otus  redundant_metadata    all                    default
otus  overlay               on                     default
otus  encryption            off                    default
otus  keylocation           none                   default
otus  keyformat             none                   default
otus  pbkdf2iters           0                      default
otus  special_small_blocks  0                      default
```
Рассмотрим подробнее основные параметры:

Размер:
```
[root@zfs-l4 ~]# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
```
Тип ФС:
```
[root@zfs-l4 ~]# zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default
```
Размер recordsize
```
[root@zfs-l4 ~]# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
```
Тип сжатия
```
[root@zfs-l4 ~]# zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local
```
Тип контрольной суммы
```
[root@zfs-l4 ~]# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```
## Работа со снапшотом
```
[root@zfs-l4 ~]# wget -O otus_task2.file --no-check-certificate "https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download"
...
2023-03-22 08:33:04 (1.13 MB/s) - ‘otus_task2.file’ saved [5432736/5432736]

[root@zfs-l4 ~]# zfs receive otus/test@today < otus_task2.file
[root@zfs-l4 ~]# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
[root@zfs-l4 ~]# cat /otus/test/task1/file_mess/secret_message
https://github.com/sindresorhus/awesome
```
**PROFIT!**

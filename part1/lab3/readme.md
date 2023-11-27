# Работа с LVM
*Работа проводилась базе чистого образа ОС Rocky Linux 9.1 с обновленным ядром*
Задание:
1) уменьшить том под / до 8G
2) выделить том под /home
3) выделить том под /var (/var - сделать в mirror)
4) для /home - сделать том для снэпшотов
5) прописать монтирование в fstab (попробовать с разными опциями и разными файловыми системами на выбор)
6) Работа со снапшотами:
- сгенерировать файлы в /home/
- снять снэпшот
- удалить часть файлов
- восстановиться со снэпшота
## Уменьшение тома /
Выведем доступные блочные устройства в системе
```
[root@lvm-l3 ~]# lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda           8:0    0 15.6G  0 disk
├─sda1        8:1    0    1G  0 part /boot
└─sda2        8:2    0 14.6G  0 part
  ├─r1-root 253:0    0 13.1G  0 lvm  /
  └─r1-swap 253:1    0  1.6G  0 lvm  [SWAP]
sdb           8:16   0   10G  0 disk
sdc           8:32   0    2G  0 disk
sdd           8:48   0    1G  0 disk
sde           8:64   0    1G  0 disk
```
Начнем подготовку к уменьшению раздела root, создадим на диске sdb для него временный раздел 
```
[root@lvm-l3 ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
[root@lvm-l3 ~]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
[root@lvm-l3 ~]# lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.
[root@lvm-l3 ~]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm-l3 ~]# mount /dev/vg_root/lv_root /mnt
```
скопируем на него все данные с root-раздела (/) и перезапишем загрузчик (grub2-mkconfig нормально не отработал, поэтому сделаем, как рекомендуется в документации к релизу для RHEL9-based дистрибутивов, по-новомодному)
```
[root@lvm-l3 ~]# xfsdump -J - /dev/r1/root | xfsrestore -J - /mnt
...
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 33 seconds elapsed
xfsrestore: Restore Status: SUCCESS
[root@lvm-l3 ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm-l3 ~]# chroot /mnt/
[root@lvm-l3 ~]# sed -i -e 's!r1-root!vg_root-lv_root!; s!r1/root!vg_root/lv_root!' /boot/loader/entries/*$(uname -r).conf
```
Обновим образы загрузки initrd
```
[root@lvm-l3 boot]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
...
dracut: *** Creating initramfs image file '/boot/initramfs-6.2.6-1.el9.elrepo.x86_64.img' done ***
[root@lvm-l3 ~]# exit
[root@lvm-l3 ~]# reboot
```
После перезагрузки проверим, что на точку монтирования / смонтировался новый временный раздел
```
[root@lvm-l3 ~]# lsblk
NAME              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                 8:0    0 15.6G  0 disk
├─sda1              8:1    0    1G  0 part /boot
└─sda2              8:2    0 14.6G  0 part
  ├─r1-swap       253:1    0  1.6G  0 lvm  [SWAP]
  └─r1-root       253:2    0 13.1G  0 lvm
sdb                 8:16   0   10G  0 disk
└─vg_root-lv_root 253:0    0   10G  0 lvm  /
sdc                 8:32   0    2G  0 disk
sdd                 8:48   0    1G  0 disk
sde                 8:64   0    1G  0 disk
```
Теперь приступим к подготовке нового постоянного уменьшенного раздела для root, удалим старый LV,
создадим новый нужного размера, на нем создадим ФС и скопируем данные обратно с временного раздела
```
[root@lvm-l3 ~]# lvremove /dev/r1/root
Do you really want to remove active logical volume r1/root? [y/n]: y
  Logical volume "root" successfully removed.
[root@lvm-l3 ~]# lvcreate -n root -L 8G r1
WARNING: xfs signature detected on /dev/r1/root at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/r1/root.
  Logical volume "root" created.
[root@lvm-l3 ~]# mkfs.xfs /dev/r1/root
meta-data=/dev/r1/root           isize=512    agcount=4, agsize=524288 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1
data     =                       bsize=4096   blocks=2097152, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm-l3 ~]# mount /dev/r1/root /mnt
[root@lvm-l3 ~]# xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
...
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 44 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```
Поправим загрузчик и образы initrd
```
[root@lvm-l3 ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm-l3 ~]# chroot /mnt/
[root@lvm-l3 /]# sed -i -e 's!vg_root-lv_root!r1-root!; s!vg_root/lv_root!r1/root!' /boot/loader/entries/*$(uname -r).conf
[root@lvm-l3 boot]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
...
dracut: *** Creating initramfs image file '/boot/initramfs-6.2.6-1.el9.elrepo.x86_64.img' done ***
```
Перезагружаться пока не будем, продолжим работу с LVM
## Новый том под /var в mirror
Сделаем отдельный новый раздел для /var
```
[root@lvm-l3 /]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
[root@lvm-l3 /]# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created
[root@lvm-l3 /]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
[root@lvm-l3 /]# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 243712 4k blocks and 60928 inodes
Filesystem UUID: 69173f7b-9b05-4a01-ac15-a6e8ac8a8a3a
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

[root@lvm-l3 /]# mount /dev/vg_var/lv_var /mnt
[root@lvm-l3 /]# cp -aR /var/* /mnt/
[root@lvm-l3 /]# rsync -avHPSAX /var/ /mnt/
sending incremental file list
./
.updated
            208 100%    0.00kB/s    0:00:00 (xfr#1, ir-chk=1021/1023)
lib/tpm2-tss/system/keystore/

sent 72,209 bytes  received 1,071 bytes  146,560.00 bytes/sec
total size is 151,412,512  speedup is 2,066.22
```
Сохраним данные со старого раздела, смонтируем новый и настроим монтирование при старте системы
```
[root@lvm-l3 /]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
[root@lvm-l3 /]# umount /mnt
[root@lvm-l3 /]# mount /dev/vg_var/lv_var /var
[root@lvm-l3 /]# echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```
После перезагрузки проверим, что / и /var монтируются правильно
```
[root@lvm-l3 ~]# lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                        8:0    0 15.6G  0 disk
├─sda1                     8:1    0    1G  0 part /boot
└─sda2                     8:2    0 14.6G  0 part
  ├─r1-root              253:0    0    8G  0 lvm  /
  └─r1-swap              253:1    0  1.6G  0 lvm  [SWAP]
sdb                        8:16   0   10G  0 disk
└─vg_root-lv_root        253:2    0   10G  0 lvm
sdc                        8:32   0    2G  0 disk
├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0 253:4    0  952M  0 lvm
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sdd                        8:48   0    1G  0 disk
├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1 253:6    0  952M  0 lvm
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sde                        8:64   0    1G  0 disk
```
Удалим созданную под временный root VG группу
```
[root@lvm-l3 ~]# lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed.
[root@lvm-l3 ~]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
[root@lvm-l3 ~]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```
## Новый том под /home и работа со снапшотами на нем
```
[root@lvm-l3 ~]# lvcreate -n home -L 2G r1
  Logical volume "home" created.
[root@lvm-l3 ~]# mkfs.xfs /dev/r1/home
meta-data=/dev/r1/home           isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm-l3 ~]# mount /dev/r1/home /mnt
[root@lvm-l3 ~]# cp -aR /home/* /mnt/
[root@lvm-l3 ~]# rm -rf /home/*
[root@lvm-l3 ~]# umount /mnt
[root@lvm-l3 ~]# mount /dev/r1/home /home/
[root@lvm-l3 ~]# echo "`blkid | grep home | awk '{print $2}'` /home xfs defaults 0 0">> /etc/fstab
```
Теперь поработаем со снапшотами, сгенерирум на /home файлы, снимем снапшот, удалим часть файлов, потом восстановим снапшот и проверим, что файлы вернулись на место.
```
[root@lvm-l3 ~]# touch /home/file{1..20}
[root@lvm-l3 ~]# ls /home/
file1   file12  file15  file18  file20  file5  file8
file10  file13  file16  file19  file3   file6  file9
file11  file14  file17  file2   file4   file7  vagrant
[root@lvm-l3 ~]# lvcreate -L 100MB -s -n home_snap /dev/r1/home
  Logical volume "home_snap" created.
[root@lvm-l3 ~]# rm -f /home/file{11..20}
[root@lvm-l3 ~]# ls /home/
file1  file10  file2  file3  file4  file5  file6  file7  file8  file9  vagrant
[root@lvm-l3 ~]# umount /home
[root@lvm-l3 ~]# lvconvert --merge /dev/r1/home_snap
  Merging of volume r1/home_snap started.
  r1/home: Merged: 100.00%
[root@lvm-l3 ~]# mount /home
[root@lvm-l3 ~]# ls /home/
file1   file12  file15  file18  file20  file5  file8
file10  file13  file16  file19  file3   file6  file9
file11  file14  file17  file2   file4   file7  vagrant
```
Файлы на месте. **Profit!!!**

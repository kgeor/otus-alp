#!/bin/bash
dnf install -y https://zfsonlinux.org/epel/zfs-release-2-2.el9.noarch.rpm
dnf install -y epel-release
dnf install -y kernel-devel dkms wget
dnf config-manager --disable zfs
dnf config-manager --enable zfs-kmod
dnf install -y zfs
modprobe zfs
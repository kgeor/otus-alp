dnf -y install epel-release
dnf -y remove kernel kernel-{core,modules,tools}
dnf -y install kernel-ml-devel gcc make bzip2 perl dkms elfutils-libelf-devel
dnf -y upgrade
echo "System upgrade done"
echo "==================="
mkdir /tmp/vboxguest
mount -t iso9660 -o loop /home/vagrant/VBoxGuestAdditions.iso /tmp/vboxguest
cd /tmp/vboxguest
echo "Starting VBox Guest Additions installation"
echo "========================================="
./VBoxLinuxAdditions.run
cd ~
umount /tmp/vboxguest
echo "Starting cleanup"
echo "================"
rm -rf /tmp/vboxguest
dnf clean all
rm -rf /home/vagrant/VBoxGuestAdditions*.iso
rm -rf /tmp/*
rm  -f /var/log/wtmp /var/log/btmp
rm -rf /var/cache/* /usr/share/doc/*
rm -rf /var/cache/yum
rm -rf /vagrant/*
rm  -f ~/.bash_history
history -c
rm -rf /run/log/journal/*
sync
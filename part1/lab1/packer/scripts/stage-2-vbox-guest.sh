dnf -y install epel-release
dnf -y remove kernel kernel-{core,modules,tools}
dnf -y install kernel-lt-devel gcc make bzip2 perl dkms elfutils-libelf-devel
dnf -y upgrade
echo "System upgrade done"
echo "==================="
mkdir /tmp/vboxguest
mount -t iso9660 -o loop /home/vagrant/VBoxGuestAdditions.iso /tmp/vboxguest
cd /tmp/vboxguest
echo "Starting VBox Guest Additions installation"
echo "=========================================="
./VBoxLinuxAdditions.run
cd ~
umount /tmp/vboxguest
dnf config-manager --set-disabled elrepo-kernel
dracut -f
reboot now
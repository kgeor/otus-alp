echo "Starting cleanup"
echo "================"
rm -rf /tmp/vboxguest
dnf clean all
rm -f /home/vagrant/VBoxGuestAdditions*.iso
rm -rf /tmp/*
rm  -f /var/log/wtmp /var/log/btmp
rm -rf /var/cache/* /usr/share/doc/*
rm -rf /var/cache/yum
rm -rf /var/cache/dnf
#rm -rf /vagrant/*
rm  -f ~/.bash_history
history -c
rm -rf /run/log/journal/*
sync
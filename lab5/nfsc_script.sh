#!/bin/bash
echo "Starting needed packages installation"
echo "====================================="
dnf -y install nfs-utils krb5-workstation pam_krb5
systemctl enable nfs-client.target
cat << EOF >> /etc/hosts
192.168.50.10 nfss.domain.local nfss
192.168.50.11 nfsc.domain.local nfsc
EOF
echo "Configuring NFS mount with krb5 auth"
echo "===================================="
echo "192.168.50.10:/srv/share/ /mnt nfs sec=krb5p,noauto,_netdev,x-systemd.automount,x-systemd.mount-timeout=10,x-systemd.idle-timeout=1min 0 0" | tee -a /etc/fstab
cp /vagrant/krb5.keytab /etc/
sed -ie 's/#    default_realm = EXAMPLE.COM/    default_realm = DOMAIN.LOCAL/; s/# EXAMPLE.COM = {/DOMAIN.LOCAL = {/;
 s/#     kdc = kerberos.example.com/     kdc = nfss.domain.local/; s/#     admin_server = kerberos.example.com/     admin_server = nfss.domain.local/;
 s/# }/ }/; s/# .example.com = EXAMPLE.COM/ .domain.local = DOMAIN.LOCAL/; s/# example.com = EXAMPLE.COM/domain.local = DOMAIN.LOCAL/' /etc/krb5.conf
kinit -k -t /etc/krb5.keytab nfs/nfsc.domain.local
sudo -u vagrant kinit -k -t /vagrant/krb5.keytab nfs/nfsc.domain.local
rm -f /vagrant/krb5.keytab
systemctl daemon-reload
systemctl restart remote-fs.target nfs-client.target
echo "Client setup is complete"
echo "========================"
echo "Checking test file"
echo "=================="
ls -l /mnt/upload
echo "Creating test file on client side"
echo "================================="
touch /mnt/upload/check_c_file
ls -l /mnt/upload
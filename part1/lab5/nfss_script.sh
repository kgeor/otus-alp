#!/bin/bash
echo "Starting needed packages installation"
echo "====================================="
dnf -y install nfs-utils krb5-server krb5-workstation pam_krb5
echo "Configuring && starting Kerberos services"
echo "========================================="
cat << EOF >> /etc/hosts
192.168.50.10 nfss.domain.local nfss
192.168.50.11 nfsc.domain.local nfsc
EOF
sed -ie 's/#    default_realm = EXAMPLE.COM/    default_realm = DOMAIN.LOCAL/; s/# EXAMPLE.COM = {/DOMAIN.LOCAL = {/;
 s/#     kdc = kerberos.example.com/     kdc = nfss.domain.local/; s/#     admin_server = kerberos.example.com/     admin_server = nfss.domain.local/;
 s/# }/ }/; s/# .example.com = EXAMPLE.COM/ .domain.local = DOMAIN.LOCAL/; s/# example.com = EXAMPLE.COM/domain.local = DOMAIN.LOCAL/' /etc/krb5.conf
sed -i 's/EXAMPLE.COM/DOMAIN.LOCAL/' /var/kerberos/krb5kdc/kadm5.acl
kdb5_util create -s -P m@sterk3y
systemctl enable krb5kdc kadmin --now
kadmin.local -q "addprinc -randkey host/nfss.domain.local"
kadmin.local -q "addprinc -randkey host/nfsc.domain.local"
kadmin.local -q "addprinc -randkey nfs/nfss.domain.local"
kadmin.local -q "addprinc -randkey nfs/nfsc.domain.local"
kadmin.local -q "ktadd host/nfss.domain.local"
kadmin.local -q "ktadd nfs/nfss.domain.local"
kadmin.local -q "ktadd -k /opt/krb5.keytab host/nfsc.domain.local"
kadmin.local -q "ktadd -k /opt/krb5.keytab nfs/nfsc.domain.local"
cp -f /opt/krb5.keytab /vagrant
echo "Configuring firewalld"
echo "====================="
firewall-cmd --add-service="nfs" \
--add-service="kerberos" \
--permanent
firewall-cmd --reload
echo "Configuring && starting NFSv4 server with krb5 auth"
echo "==================================================="
mkdir -p /srv/share/upload
chown -R nobody:nobody /srv/share
cat << EOF > /etc/exports
/srv/share 192.168.50.11(rw,sec=krb5p,sync)
EOF
systemctl enable nfs-server --now
echo "Server setup is complete"
echo "========================"
echo "Creating test file on server side"
echo "================================="
touch /srv/share/upload/check_s_file
ls -l /srv/share/upload
#--add-service="rpc-bind" \
#--add-service="mountd" \ rpcbind
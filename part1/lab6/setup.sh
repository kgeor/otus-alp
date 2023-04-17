dnf install -y --enablerepo=devel redhat-lsb-core wget rpmdevtools rpm-build createrepo dnf-utils gcc
cd /root
wget https://nginx.org/packages/centos/9/SRPMS/nginx-1.22.1-1.el9.ngx.src.rpm
rpm -i nginx-1.22.1-1.el9.ngx.src.rpm
wget https://www.openssl.org/source/openssl-3.1.0.tar.gz
tar -xf openssl-3.1.0.tar.gz
yum-builddep -y rpmbuild/SPECS/nginx.spec
echo "building is in progress"
sed -i 's%--with-debug%--with-openssl=/root/openssl-3.1.0%' rpmbuild/SPECS/nginx.spec
rpmbuild -bb rpmbuild/SPECS/nginx.spec
#dnf localinstall -y ./rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el9.ngx.x86_64.rpm
dnf -y install nginx
systemctl start nginx
mkdir /usr/share/nginx/html/repo
cp rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el9.ngx.x86_64.rpm  /usr/share/nginx/html/repo/
wget https://downloads.percona.com/downloads/percona-distribution-mysql-ps/percona-distribution-mysql-ps-8.0.32/binary/redhat/9/x86_64/percona-orchestrator-3.2.6-8.el9.x86_64.rpm -O /usr/share/nginx/html/repo/percona-orchestrator-3.2.6-8.el9.x86_64.rpm
createrepo /usr/share/nginx/html/repo
sed -i '/index  index.html index.htm;/a\       \ autoindex  on;'  /etc/nginx/conf.d/default.conf
nginx -t
nginx -s reload
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
dnf install percona-orchestrator.x86_64 -y
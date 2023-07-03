echo "Installing packages"
echo "==================="
dnf -y install s-nail
echo "Copying script and other files"
echo "=============================="
mkdir /usr/local/bin/monitoring/
chown -R vagrant /usr/local/bin/monitoring/ 
mkdir /var/log/nginx
cp /vagrant/access.log /var/log/nginx/
cp /vagrant/{script.sh,timestamp} /usr/local/bin/monitoring/
chmod +x /usr/local/bin/monitoring/script.sh
echo "Creating cron task"
echo "=================="
touch /var/spool/cron/vagrant
/usr/bin/crontab /var/spool/cron/vagrant
echo "@hourly /usr/local/bin/monitoring/script.sh /var/log/nginx/access.log $1 $2 $3" >> /var/spool/cron/vagrant
crontab -u vagrant -l

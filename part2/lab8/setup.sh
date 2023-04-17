setenforce 0
sed -i 's/enforcing/disabled/' /etc/selinux/config
systemctl stop firewalld
echo "Part1. Creating own timer-triggered service"
echo "==========================================="
echo $'# File and word in that file that we will be monitored\nWORD="ALERT"\nLOG=/var/log/watchlog.log' > /etc/sysconfig/watchlog
man echo > /var/log/watchlog.log
echo 'ALERT' >> /var/log/watchlog.log
cat << 'EOF' > /opt/watchlog.sh
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
    logger "$DATE: I found the word, Master!"
else
    exit 0
fi
EOF
chmod +x /opt/watchlog.sh
cat << 'EOF' > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
EOF
cat << EOF > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
systemctl start watchlog.timer
systemctl start watchlog.service
echo "Waiting for 35 sec"
echo "=================="
sleep 35s
echo "Check"
echo "====="
tail /var/log/messages
echo "Part2. Switch fcgi-spawn from init to unit!"
echo "==========================================="
grep -B 10 'gpgkey' -m 1 /etc/yum.repos.d/epel.repo > /etc/yum.repos.d/epel8.repo
sed -ie 's/$releasever/8/g; s/\[epel\]/\[epel8\]/; s/enabled=1/enabled=0/' /etc/yum.repos.d/epel8.repo
rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
dnf install -y --enablerepo=epel8 spawn-fcgi php php-cli mod_fcgid httpd
sed -ie 's/#SOCKET/SOCKET/; s/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi
cat << 'EOF' > /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
systemctl start spawn-fcgi
echo "Check fcgi-spawn service status"
echo "==============================="
systemctl status spawn-fcgi
echo "Part3. Setup multiple instances for Apache"
echo "=========================================="
sed -i 's$Environment=LANG=C$Environment=LANG=C\nEnvironmentFile=/etc/sysconfig/httpd-%I$' /usr/lib/systemd/system/httpd.service
echo "OPTIONS=-f conf/first.conf" > /etc/sysconfig/httpd-first
echo "OPTIONS=-f conf/second.conf" > /etc/sysconfig/httpd-second
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
sed -i 's%Listen 80%PidFile /var/run/httpd-first.pid\nListen 80%' /etc/httpd/conf/first.conf
sed -i 's%Listen 80%PidFile /var/run/httpd-second.pid\nListen 8080%' /etc/httpd/conf/second.conf
systemctl start httpd@first
systemctl start httpd@second
echo "Check Apache service status"
echo "==========================="
systemctl status httpd@first httpd@second
echo "Check Apache ports"
echo "=================="
ss -tulpn | grep httpd
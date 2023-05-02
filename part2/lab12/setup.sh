dnf -y install nginx
sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
systemctl disable --now firewalld
systemctl start nginx
systemctl status nginx
#check nginx port
ss -tlpn | grep 4881
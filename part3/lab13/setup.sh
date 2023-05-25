#setenforce 0
#sed -i 's/enforcing/disabled/' /etc/selinux/config
#systemctl stop firewalld
echo "Installing Docker"
echo "================="
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker vagrant
systemctl --now enable docker
echo "Building & starting container"
echo "============================="
cd /vagrant/
docker build -t rocky-nginx .
docker run -d -p 80:80 -p 3000:3000 rocky-nginx
echo "Container is running. NGINX serving 2 sites on 80 and 3000 ports"
echo "================================================================"
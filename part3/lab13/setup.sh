#setenforce 0
#sed -i 's/enforcing/disabled/' /etc/selinux/config
#systemctl stop firewalld
echo "Installing Docker"
echo "================="
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker vagrant
systemctl --now enable docker
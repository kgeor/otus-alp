#setenforce 0
#sed -i 's/enforcing/disabled/' /etc/selinux/config
sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "Creating users"
echo "=============="
useradd otusadm && useradd otus
echo "Otus2023!" | passwd --stdin otusadm && echo "Otus2023!" | passwd --stdin otus
groupadd -f admin
usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
echo "Setting PAM modules"
echo "==================="
cat << 'EOF' > /usr/local/bin/login.sh
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
EOF
chmod +x /usr/local/bin/login.sh
sed -i 's%account    required     pam_nologin.so%account    required     pam_nologin.so\naccount    required     pam_exec.so /usr/local/bin/login.sh%' /etc/pam.d/sshd
echo "Installing & configuring Docker for user otus"
echo "============================================="
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker otus
cat > /etc/polkit-1/rules.d/10-docker.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "docker.service" &&
        subject.user == "otus") {
        return polkit.Result.YES;
    }
})
EOF

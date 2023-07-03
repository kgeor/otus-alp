echo "Installing Ansible"
echo "=================="
dnf -y install ansible
cp -r /vagrant/ansible ./
cp /vagrant/.vagrant/machines/ans-managed-host/virtualbox/private_key ansible/inventory/client_private_key
chown -R vagrant:vagrant ansible/
echo "Setting up role NGINX on client"
echo "==============================="
cd ansible/
ansible-playbook nginx.yml
echo "Check NGINX test page is available"
echo "============================================"
curl http://192.168.50.11:8080
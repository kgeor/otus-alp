#! /bin/bash
echo "Generating TLS self-signed certificate for 'site.local' domain"
openssl req -x509 -nodes -days 365 \
-newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -keyout /home/vagrant/project/config/nginx/certs/local.key \
-out /home/vagrant/project/config/nginx/certs/local.crt -config /home/vagrant/project/config/nginx/certs/.local.cnf
FROM rockylinux:9.1
RUN dnf -y install epel-release && dnf -y install nginx \
&& chown -R nginx. /usr/share/nginx/html/ \
&& dnf clean all \
&& rm -rf /tmp/* && rm -rf /var/cache/* \
&& mkdir /usr/share/nginx/html/site1 \
&& mkdir /usr/share/nginx/html/site2
#&& ln -sf /dev/stdout /var/log/nginx/access.log \
#&& ln -sf /dev/stderr /var/log/nginx/error.log
#WORKDIR /etc/nginx
COPY nginx/nginx.conf /etc/nginx/
COPY nginx/site1.conf /etc/nginx/conf.d/
COPY nginx/site2.conf /etc/nginx/conf.d/
ADD nginx/site1 /usr/share/nginx/html/site1
ADD nginx/site2 /usr/share/nginx/html/site2
VOLUME /usr/share/nginx/html
VOLUME /var/log/nginx/
EXPOSE 80
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
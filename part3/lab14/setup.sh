#setenforce 0
#sed -i 's/enforcing/disabled/' /etc/selinux/config
systemctl disable --now firewalld
dnf -y update
echo "Installing Prometheus"
echo "====================="
wget -q https://github.com/prometheus/prometheus/releases/download/v2.44.0/prometheus-2.44.0.linux-amd64.tar.gz
useradd --no-create-home --shell /sbin/nologin prometheus
mkdir /etc/prometheus
mkdir /var/lib/prometheus
chown prometheus. /etc/prometheus
chown prometheus. /var/lib/prometheus
tar -xzf prometheus-2.44.0.linux-amd64.tar.gz 
mv prometheus-2.44.0.linux-amd64 prometheuspackage
cp prometheuspackage/prometheus /usr/local/bin/
cp prometheuspackage/promtool /usr/local/bin/
chown prometheus. /usr/local/bin/prometheus
chown prometheus. /usr/local/bin/promtool
cp -r prometheuspackage/consoles /etc/prometheus
cp -r prometheuspackage/console_libraries /etc/prometheus
chown -R prometheus:prometheus /etc/prometheus/consoles
chown -R prometheus:prometheus /etc/prometheus/console_libraries
touch /etc/prometheus/prometheus.yml
chown prometheus:prometheus /etc/prometheus/prometheus.yml
cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
          --config.file /etc/prometheus/prometheus.yml \
          --storage.tsdb.path /var/lib/prometheus/ \
          --web.console.templates=/etc/prometheus/consoles \
          --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
echo "Installing Node Exporter"
echo "========================"
wget -q  https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar xzf node_exporter-1.5.0.linux-amd64.tar.gz
useradd -rs /sbin/nologin nodeusr
mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/
cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
echo "Installing AlertManager"
echo "======================="
wget -q https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz
tar xzf alertmanager-0.25.0.linux-amd64.tar.gz
useradd --no-create-home --shell /sbin/nologin alertmanager
usermod --home /var/lib/alertmanager alertmanager
mkdir /etc/alertmanager
mkdir /var/lib/alertmanager
cp alertmanager-0.25.0.linux-amd64/amtool /usr/local/bin/
cp alertmanager-0.25.0.linux-amd64/alertmanager /usr/local/bin/
cp alertmanager-0.25.0.linux-amd64/alertmanager.yml /etc/alertmanager/
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
chown alertmanager:alertmanager /usr/local/bin/{alertmanager,amtool}
echo "ALERTMANAGER_OPTS=\"\"" > /etc/default/alertmanager
chown alertmanager:alertmanager /etc/default/alertmanager
cat << EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager Service
After=network.target prometheus.service

[Service]
EnvironmentFile=-/etc/default/alertmanager
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
          --config.file=/etc/alertmanager/alertmanager.yml \
          --storage.path=/var/lib/alertmanager \
          $ALERTMANAGER_OPTS
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
Restart=always

[Install]
WantedBy=multi-user.target
EOF
cat << EOF > /etc/prometheus/rules.yml
groups:
- name: alert.rules
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute.'
      summary: Instance {{ $labels.instance }} down
EOF
cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 10s
scrape_configs:
  - job_name: 'prometheus_master'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_rocky'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']

rule_files:
  - "rules.yml"
alerting:
  alertmanagers:
    - static_configs:
      - targets:
        - localhost:9093
EOF
echo "Installing Grafana"
echo "=================="
dnf -y install /vagrant/grafana-enterprise-9.5.2-1.x86_64.rpm
systemctl daemon-reload
systemctl --now enable prometheus
systemctl --now enable node_exporter
systemctl --now enable alertmanager
systemctl --now enable grafana-server
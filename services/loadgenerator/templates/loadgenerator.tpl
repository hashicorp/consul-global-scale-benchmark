#!/bin/bash

echo "Configuring user....."
sudo mkdir -p "/home/ubuntu/.cache"
sudo touch "/home/ubuntu/.cache/motd.legal-displayed"
sudo touch "/home/ubuntu/.sudo_as_admin_successful"
sudo chown -R "ubuntu:ubuntu" "/home/ubuntu"

echo "Configuring MOTD....."
sudo rm -rf /etc/motd
sudo rm -rf /var/run/motd
sudo rm -rf /etc/update-motd.d/*
sudo tee /etc/motd > /dev/null <<"EOF"                                                                                            
Hello there, this is a loadgenerator!
EOF

export INTERNAL_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
export PUBLIC_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

# Install unzip and dnsmasq
apt-get update && apt-get install -y unzip dnsmasq vim nginx htop

## Setup consul
mkdir -p /var/lib/consul
mkdir -p /etc/consul.d

# Fetch Consul
cd /tmp
CONSUL_DOWNLOAD_URL="${consul_download_url}"
if [ -z $${CONSUL_DOWNLOAD_URL} ];
then 
  echo "using releases.hashicorp.com to download consul"
  wget https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip -O ./consul.zip
  unzip ./consul.zip
else 
  echo "using download url '$CONSUL_DOWNLOAD_URL' to download consul"
  curl -sL --fail -o ./consul "$CONSUL_DOWNLOAD_URL"
fi

chmod +x ./consul
mv ./consul /usr/local/bin

# Create the consul config
mkdir -p /etc/consul/config

cat << EOF > /etc/consul/config.hcl
data_dir = "/var/lib/consul"
log_level = "DEBUG"
datacenter = "${consul_datacenter}"
encrypt = "${consul_gossip_encryption_key}"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
ports {
  grpc = 8502
}
connect {
  enabled = true
}
use_streaming_backend = true
http_config {
  use_cache = true
}
dns_config {
  use_cache = true
}
enable_central_service_config = true
advertise_addr = "$INTERNAL_IP_ADDRESS"
retry_join = ["provider=aws tag_key=${retry_join_tag} tag_value=${retry_join_tag}"]

# TLS config
verify_incoming = false
verify_outgoing = true
verify_server_hostname = true
ca_file = "/etc/consul/tls/ca_cert.pem"
auto_encrypt = {
  tls = true
}

telemetry {
  dogstatsd_addr = "127.0.0.1:8125"
}
limits {
  http_max_conns_per_client = ${consul_http_max_conns_per_client}
}
# Enable remote execution to allow for consul exec commands to stop loadgenerators
disable_remote_exec = false
EOF

cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul
Documentation=https://consul.io/docs/

[Service]
ExecStart=/usr/local/bin/consul agent \
  -config-file=/etc/consul/config.hcl \
  -enable-script-checks

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl start consul

# Configure dnsmasq
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/10-consul <<'EOF'
server=/consul/127.0.0.1#8600
EOF

systemctl enable dnsmasq
systemctl start dnsmasq
# Force restart for adding consul dns
systemctl restart dnsmasq

# Install consul-template

curl \
  --silent \
  --location \
  --output consul-template.tgz \
  https://releases.hashicorp.com/consul-template/0.25.1/consul-template_0.25.1_linux_amd64.tgz
tar -xvf consul-template.tgz
mv consul-template /usr/local/bin/consul-template
rm consul-template.tgz

cat << EOF > /etc/consul/consul-template-config.hcl
consul {
  address = "localhost:8500"

  retry {
    enabled  = true
    attempts = 12
    backoff  = "250ms"
  }
}
template {
  source      = "/etc/nginx/conf.d/tier-1-service.conf.tpl"
  destination = "/etc/nginx/conf.d/tier-1-service.conf"
  perms       = 0600
  command     = "service nginx reload"
}
EOF

cat << EOF > /etc/nginx/conf.d/tier-1-service.conf.tpl
upstream backend {
{{- range services}}{{\$service := .Name}}{{\$tag := "tier-1"}}
  {{- if (.Tags | contains "tier-1") }}
  {{- range service (printf "%s" \$service) }}
  {{- if ne .Port 20000 }}
  server {{ .Address }}:{{ .Port }};
  {{end}}
  {{end}}
  {{end}}
{{ end }}
}

server {
   listen 0.0.0.0:9090;

   location / {
      proxy_pass http://backend;
   }
}

EOF

echo "consul-template systemd file"

cat << EOF > /etc/systemd/system/consul-template.service
[Unit]
Description=consul-template
Documentation=https://github.com/hashicorp/consul-template

[Service]
ExecStart=/usr/local/bin/consul-template \
  -config=/etc/consul/consul-template-config.hcl

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul-template

echo "download slow_cooker"

wget https://github.com/BuoyantIO/slow_cooker/releases/download/1.2.0/slow_cooker_linux_amd64 -O /usr/local/bin/slow_cooker
chmod +x /usr/local/bin/slow_cooker

# create a directory to store slow_cooker logs and results
sudo mkdir -p /home/ubuntu/slow_cooker
sudo chown -R "ubuntu:ubuntu" /home/ubuntu/slow_cooker 

# Install datadog agent

echo "install datadog agent"

DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=${datadog_api_key} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

cat << EOF > /etc/datadog-agent/conf.d/prometheus.d/conf.yaml
init_config:

instances:

    ## @param prometheus_url - string - required
    ## The URL where your application metrics are exposed by Prometheus.
    #
  - prometheus_url: http://localhost:9102/metrics

    ## @param namespace - string - required
    ## The namespace to be appended before all metrics namespace
    #
    namespace: slow_cooker

    ## @param metrics - list of key:value elements - required
    ## List of <METRIC_TO_FETCH>: <NEW_METRIC_NAME> for metrics to be fetched from the prometheus endpoint.
    ## <NEW_METRIC_NAME> is optional. It transforms the name in Datadog if set.
    ## This list should contain at least one metric
    #
    metrics:
      - go_*
      - latency*
      - requests
      - successes
      - process*
    tags:
      - consul_datacenter:${consul_datacenter}
EOF

# Enable logging via datadog agent
cat <<EOT >> /etc/datadog-agent/datadog.yaml
logs_enabled: true
tags: [internal_ip_address:$INTERNAL_IP_ADDRESS", "external_ip_address:$PUBLIC_IP_ADDRESS"]
EOT

# Enable logging for slow_cooker
mkdir -p /etc/datadog-agent/conf.d/slow_cooker.d
cat <<EOT >> /etc/datadog-agent/conf.d/slow_cooker.d/conf.yaml
logs:
  - type: file
    path: "/home/ubuntu/slow_cooker/slow_cooker.log"
    service: "slow_cooker"
    source: "loadgenerator"
EOT

echo "restart datadog-agent"
systemctl restart datadog-agent

echo "start consul template"

systemctl start consul-template
systemctl restart nginx

echo "start slow_cooker"

exec /usr/local/bin/slow_cooker -qps ${qps} -concurrency ${concurrency} -metric-addr "0.0.0.0:9102" -interval 10s -reportLatenciesCSV /home/ubuntu/slow_cooker/latency.csv http://127.0.0.1:9090 | sudo tee /home/ubuntu/slow_cooker/slow_cooker.log


























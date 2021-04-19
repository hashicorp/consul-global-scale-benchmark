#!/bin/bash

export INTERNAL_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
export PUBLIC_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Setting hostname....."
sudo tee /etc/hostname > /dev/null <<"EOF"
${hostname}
EOF
sudo hostname -F /etc/hostname
sudo tee -a /etc/hosts > /dev/null <<EOF
# For local resolution
$INTERNAL_IP_ADDRESS  ${hostname}
EOF

apt-get update && apt-get install -y unzip jq

# Disable ratelimiting in journald
echo "RateLimitIntervalSec=0" >> /etc/systemd/journald.conf
echo "RateLimitBurst=0" >> /etc/systemd/journald.conf

systemctl restart systemd-journald

# Disable ratelimiting in rsyslog
echo "\$SystemLogRateLimitInterval 0" >> /etc/rsyslog.conf
echo "\$SystemLogRateLimitBurst 0" >> /etc/rsyslog.conf
echo "\$IMUxSockRateLimitBurst 0" >> /etc/rsyslog.conf
echo "\$IMUXSockRateLimitInterval 0" >> /etc/rsyslog.conf

systemctl restart rsyslog

# Install datadog agent
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=${datadog_api_key} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Enable consul checks
mv /etc/datadog-agent/conf.d/consul.d/conf.yaml.example /etc/datadog-agent/conf.d/consul.d/conf.yaml

systemctl restart datadog-agent

# This allows datadog to finish coming online and
# capture all logs for the system services like consul
sleep 5

# Fetch Consul
cd /tmp
CONSUL_DOWNLOAD_URL="${consul_download_url}"
if [ -z $${CONSUL_DOWNLOAD_URL+x} ];
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

# Install Envoy
apt-get install -y \
apt-transport-https \
ca-certificates \
curl \
gnupg-agent \
software-properties-common

curl -sL 'https://getenvoy.io/gpg' | sudo apt-key add -

sudo add-apt-repository \
"deb [arch=amd64] https://dl.bintray.com/tetrate/getenvoy-deb \
$(lsb_release -cs) \
stable"

apt-get update && sudo apt-get install -y getenvoy-envoy=${envoy_version}

## Setup consul
mkdir -p /var/lib/consul
mkdir -p /etc/consul.d

# Create the consul config
mkdir -p /etc/consul
cat << EOF > /etc/consul/config.hcl
data_dir = "/tmp/"
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

use_streaming_backend = ${consul_cache_use_streaming_backend}

http_config {
  use_cache = ${consul_http_config_use_cache}
}
dns_config {
  use_cache = ${consul_dns_config_use_cache}
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
EOF

# Setup systemd
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul
After=syslog.target network.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-file=/etc/consul/config.hcl
ExecStop=/bin/sleep 5
KillMode=process
KillSignal=SIGTERM
Restart=always

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/consul.service

# Setup system D
cat << EOF > /etc/systemd/system/consul-gateway.service
[Unit]
Description=Consul Gateway
After=syslog.target network.target

[Service]
ExecStart=/usr/local/bin/consul connect envoy -gateway=mesh -register -wan-address "$PUBLIC_IP_ADDRESS:8443" -- -l debug
ExecStop=/bin/sleep 5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/consul-gateway.service

systemctl daemon-reload
systemctl start consul.service
systemctl start consul-gateway.service

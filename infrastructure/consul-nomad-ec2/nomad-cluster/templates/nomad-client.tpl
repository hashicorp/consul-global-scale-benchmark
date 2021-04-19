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
                                    @@@@@                                    
                                @@@@@@@@@@@@                                 
                             @@@@@@@@@@@@@@@@@@@                             
                         @@@@@@@@@@@@@@@@@@@@@@@@@@@                         
                      @@@@@@@@@@@@@@@@@@@@@@  @@@@@@@@@                      
                      @@@@@@@@@@@@@@@@@@@     @@@@@@@@@                      
                      @@@@@@@@@@@@@@@@@@@     @@@@@@@@@                      
                      @@@@@@@@@@@@   @@@@     @@@@@@@@@                      
                      @@@@@@@@@         @     @@@@@@@@@                      
                      @@@@@@@@@               @@@@@@@@@                      
                      @@@@@@@@@     @@@     @@@@@@@@@@@                      
                      @@@@@@@@@     @@@@@@@@@@@@@@@@@@@                      
                      @@@@@@@@@     @@@@@@@@@@@@@@@@@@@                      
                      @@@@@@@@@   @@@@@@@@@@@@@@@@@@@@@                      
                         @@@@@@@@@@@@@@@@@@@@@@@@@@@                         
                            @@@@@@@@@@@@@@@@@@@@@                            
                                @@@@@@@@@@@@@                                
                                   @@@@@@@                                   
                                                                                                                                        
                 @@@    @@                                @@                 
                 @@@@   @@   @@       @@   @    @@     @@ @@                 
                 @@ @@  @@ @@  @@  @@@ @@@ @@     @@ @@   @@                 
                 @@  @@ @@ @@  @@  @@  @@  @@  @@@@@ @@   @@                 
                 @@   @@@@ @@@ @@  @@  @@  @@ @@  @@ @@@@@@@                             
        
Hello there, this is a Nomad client! Have fun exploring :)
EOF

export INTERNAL_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
export PUBLIC_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
export HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/hostname)

# Set an environment variable to turn on grpc server shuffle
export CONSUL_SERVER_SHUFFLE=true
IFS='- ' read -r -a array <<< "$HOSTNAME"
if (( array[3] % 2 == 0 ))
then
  CONSUL_SERVER_SHUFFLE=false
else
  echo "CONSUL_SERVER_SHUFFLE is set to true"
fi

echo "CONSUL_SERVER_SHUFFLE=$CONSUL_SERVER_SHUFFLE"

apt-get update
# Install unzip, dnsmasq, docker, git, vim, and htop
apt-get install -y unzip dnsmasq docker.io git vim htop jq

# Disable ratelimiting in journald to allow for debug and trace level logs to be logged to journald
echo "RateLimitIntervalSec=0" >> /etc/systemd/journald.conf
echo "RateLimitBurst=0" >> /etc/systemd/journald.conf

systemctl restart systemd-journald

# Disable ratelimiting in rsyslog
echo "\$SystemLogRateLimitInterval 0" >> /etc/rsyslog.conf
echo "\$SystemLogRateLimitBurst 0" >> /etc/rsyslog.conf
echo "\$IMUxSockRateLimitBurst 0" >> /etc/rsyslog.conf
echo "\$IMUXSockRateLimitInterval 0" >> /etc/rsyslog.conf

systemctl restart rsyslog

DATADOG_API_KEY="${datadog_api_key}"
if [ -z "$${DATADOG_API_KEY}" ];
then
  echo "skipping datadog agent install"
else
  echo "installing datadog agent"
  # Install datadog agent
  DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$${DATADOG_API_KEY} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

  # Enable docker checks for datadog
  mv /etc/datadog-agent/conf.d/docker.d/conf.yaml.example /etc/datadog-agent/conf.d/docker.d/conf.yaml

  # Bind datadog agent to 0.0.0.0
  echo "bind_host: 0.0.0.0" >> /etc/datadog-agent/datadog.yaml

  # Enable consul checks for datadog
  mv /etc/datadog-agent/conf.d/consul.d/conf.yaml.example /etc/datadog-agent/conf.d/consul.d/conf.yaml

  # Allow datadog agent to access docker
  usermod -a -G docker dd-agent

  # Allow datadog agent to access journald logs
  usermod -a -G systemd-journal dd-agent

  # Enable logging via datadog agent
  cat <<EOT >> /etc/datadog-agent/datadog.yaml
logs_enabled: true
listeners:
    - name: docker
config_providers:
    - name: docker
      polling: true
logs_config:
    container_collect_all: true
    processing_rules:
      - type: exclude_at_match
        name: exclude_global_log_entries
        pattern: "flushing|socket|cleanup|discouraged|Check|Request finished|agent.envoy: generating|agent: Service in sync|Synced check|agent.client.serf.lan" # this is to allow for TRACE level logging and shipping to datadog.
tags: ["consul_server_shuffle:$CONSUL_SERVER_SHUFFLE", "internal_ip_address:$INTERNAL_IP_ADDRESS", "external_ip_address:$PUBLIC_IP_ADDRESS"]
EOT

  # Enable journald logs for consul and nomad via datadog agent
  mkdir -p /etc/datadog-agent/conf.d/journald.d/
  cat <<EOT >> /etc/datadog-agent/conf.d/journald.d/conf.yaml
 logs:
   - type: journald
     path: /run/log/journal/
     source: nomad_client
     include_units:
      - consul.service
      - nomad.service
     tags: ["consul_server_shuffle:$CONSUL_SERVER_SHUFFLE", "internal_ip_address:$INTERNAL_IP_ADDRESS", "external_ip_address:$PUBLIC_IP_ADDRESS"]
EOT

  systemctl restart datadog-agent
fi

NOMAD_CLIENT_RANDOM_STARTUP_WAIT_TIME_MAX=${nomad_client_random_startup_wait_time_max}
if [ $${NOMAD_CLIENT_RANDOM_STARTUP_WAIT_TIME_MAX} -eq 0 ];
then
  echo "not sleeping, continuing....."
else
  # Sleep for a random amount of time between 1-20 mins. This is to allow for a faster scale up while running large node counts.
  echo "sleeping....."
  sleep $[ ( $RANDOM % $NOMAD_CLIENT_RANDOM_STARTUP_WAIT_TIME_MAX )  + 1 ]s
fi

## Setup consul
mkdir -p /var/lib/consul

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

# Create the consul config
mkdir -p /etc/consul/config

cat << EOF > /etc/consul/config.hcl
data_dir = "/var/lib/consul"
log_level = "${consul_client_log_level}"
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
limits {
  http_max_conns_per_client = ${consul_http_max_conns_per_client}
}
EOF

# Create consul systemd service file
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul
Documentation=https://consul.io/docs/

[Service]
Environment="CONSUL_SERVER_SHUFFLE=$CONSUL_SERVER_SHUFFLE"
ExecStart=/usr/local/bin/consul agent \
  -config-file=/etc/consul/config.hcl \
  -enable-script-checks

ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl start consul

# Install consul-template
curl \
  --silent \
  --location \
  --output consul-template.tgz \
  https://releases.hashicorp.com/consul-template/0.25.1/consul-template_0.25.1_linux_amd64.tgz
tar -xvf consul-template.tgz
mv consul-template /usr/local/bin/consul-template
rm consul-template.tgz

# move consul-template watch config
mv /tmp/consul-template-kv-shutdown-watch.tpl /etc/consul/consul-template-kv-shutdown-watch.tpl

# consul-template config
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
  source      = "/etc/consul/consul-template-kv-shutdown-watch.tpl"
  destination = "/usr/local/bin/consul-template-kv-shutdown-watch.sh"
  perms       = 0755
  command     = "/usr/local/bin/consul-template-kv-shutdown-watch.sh"
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

systemctl start consul-template

# Configure dnsmasq
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/10-consul <<'EOF'
server=/consul/127.0.0.1#8600
EOF

systemctl enable dnsmasq
systemctl start dnsmasq
# Force restart for adding consul dns
systemctl restart dnsmasq

# Download and install nomad
curl \
  --silent \
  --location \
  --output nomad.zip \
  https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
unzip nomad.zip
mv nomad /usr/local/bin/nomad
rm nomad.zip

mkdir -p /var/lib/nomad
mkdir -p /etc/nomad

cat << EOF > /etc/nomad/client.hcl
addresses {
    rpc  = "$INTERNAL_IP_ADDRESS"
    http = "$INTERNAL_IP_ADDRESS"
}
advertise {
    http = "$INTERNAL_IP_ADDRESS:4646"
    rpc  = "$INTERNAL_IP_ADDRESS:4647"
}
datacenter = "${nomad_datacenter}"
region = "${nomad_region}"
data_dir  = "/var/lib/nomad"
log_level = "${nomad_client_log_level}"
enable_debug = true
client {
    enabled = true
    # Limit resources used by client gc
    gc_max_allocs = 300
    gc_parallel_destroys = 1

    # Enable raw exec
    options {
      "driver.raw_exec.enable" = "1"
      "alloc.rate_limit" = "50"
      "alloc.rate_burst" = "2"
    }

    # Use specified version of envoy image
    meta {
      "connect.sidecar_image" = "${nomad_envoy_image}"
      "connect.log_level"     = "${nomad_envoy_log_level}"
    }
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  datadog_address = "localhost:8125"
  disable_hostname = true
  collection_interval = "10s"
}
EOF

# Create nomad systemd service file
cat << EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

# Configure CNI plugins for consul connect
curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

cat << EOF > /etc/sysctl.d/99-bridge-network-iptables.conf
# Ensure the your Linux operating system distribution has been configured to allow container
# traffic through the bridge network to be routed via iptables. The below configuration preserves the settings
# Reference: https://www.nomadproject.io/guides/integrations/consul-connect/index.html#cni-plugins
net.bridge.bridge-nf-call-arptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF

# Enable and start nomad service
systemctl enable nomad
systemctl start nomad































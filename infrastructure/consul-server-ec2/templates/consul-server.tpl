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
                                                              
                             @@@@@@@@@                               
                         @@@@@@@@@@@@@@@@@@                          
                      @@@@@@@          @@@@                          
                     @@@@@                                           
                   @@@@                       @@@                    
                  @@@@                                               
                  @@@                       @@   @@                  
                 @@@@          @@@@@@       @@@ @@@@                 
                 @@@@         @@@@@@@  @@@@                          
                 @@@@          @@@@@@       @@@  @@@                 
                  @@@                       @@@  @@                  
                  @@@@                                               
                   @@@@                       @@@                    
                    @@@@@                                            
                      @@@@@@            @@@                          
                        @@@@@@@@@@@@@@@@@@@                          
                            @@@@@@@@@@@                              
                                                                                                        
                  @@@@@                           @@                 
                 @@      @@@@  @@@@@  @@@@ @@  @@ @@                 
                 @@     @   @@ @  @@ @@    @@  @@ @@                 
                 @@     @   @@ @  @@    @@ @@  @@ @@                 
                  @@@@@ @@@@@  @  @@ @@@@@ @@@@@@ @@                 
        
Hello there, this is a Consul server! Have fun exploring :)
EOF

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

apt-get update && apt-get install -y unzip jq htop

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

DATADOG_API_KEY="${datadog_api_key}"
if [ -z "$${DATADOG_API_KEY}" ];
then
  echo "skipping datadog agent install"
else
  echo "installing datadog agent"
  # Install datadog agent
  DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$${DATADOG_API_KEY} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

  # Enable consul checks for datadog
  mv /etc/datadog-agent/conf.d/consul.d/conf.yaml.example /etc/datadog-agent/conf.d/consul.d/conf.yaml

  # Allow datadog agent to access journald logs
  usermod -a -G systemd-journal dd-agent

  # Enable journald logs for consul and nomad via datadog agent
  mkdir -p /etc/datadog-agent/conf.d/journald.d/
  cat <<EOT >> /etc/datadog-agent/conf.d/journald.d/conf.yaml
 logs:
   - type: journald
     path: /run/log/journal/
     source: consul_server
     include_units:
      - consul.service
EOT

  # Enable log shipping via datadog agent
  cat <<EOT >> /etc/datadog-agent/datadog.yaml
logs_enabled: true
EOT

  systemctl restart datadog-agent

  # This allows datadog to finish coming online and 
  # capture all logs for the system services like consul
  sleep 5
fi

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
mkdir -p /etc/consul
mkdir -p /mnt/consul

MOUNT_SSD_VOLUME=${mount_ssd_volume}
if $MOUNT_SSD_VOLUME ;
then
  echo "waiting for ebs volume to be mounted"
  # wait for ebs disk to be mounted
  while ! ls /dev/nvme1n1 > /dev/null
  do
    sleep 5
  done
  echo "disk mounted"
  mkfs -t ext4 /dev/nvme1n1
  mount /dev/nvme1n1 /mnt/consul
  echo /dev/nvme1n1  /mnt/consul  ext4 defaults,nofail 0 2 >> /etc/fstab
else
  echo "using default disk"
fi

cat << EOF > /etc/consul/config.hcl
data_dir = "/mnt/consul"
log_level = "${consul_log_level}"

datacenter = "${consul_datacenter}"
primary_datacenter = "${consul_primary_datacenter}"
encrypt = "${gossip_encryption_key}"

server = true
enable_debug = true

bootstrap_expect = ${consul_server_count}
ui_config {
  enabled = true
}

bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

ports {
  grpc = 8502
}

connect {
  enabled = true
  ca_config {
    # We have 36 core cpu on the servers, so its safe to set
    # csr_max_concurrent to 12 and disable rate limiting.
    csr_max_concurrent = 12
    csr_max_per_second = 0
  }
}

rpc {
  enable_streaming = ${enable_streaming}
}

enable_central_service_config = true

advertise_addr = "$INTERNAL_IP_ADDRESS"
advertise_addr_wan = "$PUBLIC_IP_ADDRESS"
retry_join_wan = ["${primary_cluster_addr}"]
retry_join = ["provider=aws tag_key=${retry_join_tag} tag_value=${retry_join_tag}"]

# TLS config
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
ca_file = "/etc/consul/tls/ca_cert.pem"
cert_file = "/etc/consul/tls/cert.pem"
key_file = "/etc/consul/tls/key.pem"
auto_encrypt {
  allow_tls = true
}

telemetry {
  dogstatsd_addr = "127.0.0.1:8125"
}

# Server performance config
limits {
  rpc_max_conns_per_client = 2000
  http_max_conns_per_client = 2000
}
EOF

# Create consul systemd service file
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul Server
After=syslog.target network.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-file=/etc/consul/config.hcl
ExecStop=/bin/sleep 5
Restart=always
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/consul.service

systemctl daemon-reload
systemctl start consul.service

echo "Finished installing and configuring consul."

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
        
Hello there, this is a Nomad server! Have fun exploring :)
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

# Install unzip
apt-get update && apt-get install -y unzip jq htop

# Install datadog agent
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=${datadog_api_key} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Enable consul checks for datadog
mv /etc/datadog-agent/conf.d/consul.d/conf.yaml.example /etc/datadog-agent/conf.d/consul.d/conf.yaml

systemctl restart datadog-agent

## Setup consul
mkdir -p /var/lib/consul

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
log_level = "${consul_client_log_level}"
datacenter = "${consul_datacenter}"
encrypt = "${consul_gossip_encryption_key}"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
ports {
  grpc = 8502
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

# Create consul systemd service file
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul
Documentation=https://consul.io/docs/

[Service]
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

## Download and install nomad
curl \
  --silent \
  --location \
  --output nomad.zip \
  https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
unzip nomad.zip
mv nomad /usr/local/bin/nomad
rm nomad.zip

# Create the nomad config
mkdir -p /etc/nomad
mkdir -p /mnt/nomad

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
  mount /dev/nvme1n1 /mnt/nomad
  echo /dev/nvme1n1  /mnt/nomad  ext4 defaults,nofail 0 2 >> /etc/fstab
else
  echo "using default disk"
fi

cat << EOF > /etc/nomad/server.hcl
addresses {
    rpc  = "$INTERNAL_IP_ADDRESS"
    serf = "$INTERNAL_IP_ADDRESS"
}

advertise {
    http = "$INTERNAL_IP_ADDRESS:4646"
    rpc  = "$INTERNAL_IP_ADDRESS:4647"
    serf = "$INTERNAL_IP_ADDRESS:4648"
}

bind_addr = "0.0.0.0"
datacenter = "${nomad_datacenter}"
region = "${nomad_region}"
data_dir  = "/mnt/nomad"
log_level = "${nomad_server_log_level}"
enable_debug = true

server {
    enabled = true
    bootstrap_expect = ${nomad_server_count}

    default_scheduler_config {
      scheduler_algorithm = "${nomad_scheduler_algorithm}"
    }

    # Performance and scheduler config
    # This was taken from Nomad C2M Challenge (https://hashicorp.com/c2m)
    # raft_multiplier is set to 5 to take into consideration long pauses or network issues
    raft_multiplier = 5
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  datadog_address = "localhost:8125"
  disable_hostname = true
  collection_interval = "10s"
}
EOF

# Create nomad systemd file
cat << EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/

[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
LimitNPROC=infinity
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

# Enable and start nomad service
systemctl enable nomad
systemctl start nomad





























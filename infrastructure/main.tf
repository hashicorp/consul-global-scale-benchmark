# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 0.13.0"
}

provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
}

provider "aws" {
  alias   = "use1"
  version = ">= 2.28.1"
  region  = "us-east-1"
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "null_resource" "save_key" {
  triggers = {
    key = tls_private_key.ssh_key.private_key_pem
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/.ssh
      echo "${tls_private_key.ssh_key.private_key_pem}" > ${path.module}/.ssh/id_rsa
      chmod 0600 ${path.module}/.ssh/id_rsa
EOF
  }
}

module "consul-eks" {
  source = "./consul-eks"

  region                            = var.region
  project                           = "${var.project}-eks"
  key_name                          = var.key_name
  ssh_public_key                    = tls_private_key.ssh_key.public_key_openssh
  consul_datacenter                 = var.eks_consul_datacenter
  consul_version                    = var.consul_version
  consul_server_count               = var.eks_consul_server_count
  consul_server_instance_type       = var.eks_consul_server_instance_type
  worker_group_asg                  = var.worker_group_asg
  consul_primary_datacenter         = var.consul_primary_datacenter
  datadog_api_key                   = var.datadog_api_key
  enable_streaming_servers          = var.eks_enable_streaming_servers
  enable_streaming_clients          = var.eks_enable_streaming_clients
  consul_global_image               = var.eks_consul_global_image
  consul_envoy_global_image         = var.eks_consul_envoy_global_image
  consul_envoy_global_image_version = var.eks_consul_envoy_global_image_version
  consul_k8s_global_image           = var.eks_consul_k8s_global_image
  consul_client_log_level           = var.eks_consul_client_log_level
  consul_server_log_level           = var.eks_consul_server_log_level
  consul_enable_ui_elb              = var.eks_consul_enable_ui_elb
  consul_download_url               = var.eks_consul_download_url
  consul_envoy_log_level            = var.eks_consul_envoy_log_level
  consul_tls_ca_cert_pem            = tls_self_signed_cert.ca_cert.cert_pem
  consul_tls_server_cert_pem        = tls_locally_signed_cert.server_cert.cert_pem
  consul_tls_server_key_pem         = tls_private_key.server_key.private_key_pem
  consul_gossip_encryption_key      = random_id.consul_gossip_encrypt.hex
  consul_helm_chart_version         = var.eks_consul_helm_chart_version
  consul_mount_ssd_volume           = var.eks_consul_mount_ssd_volume
}

module "consul-nomad-ec2" {
  source = "./consul-nomad-ec2"

  providers = {
    aws = aws.use1
  }

  region                                    = "us-east-1"
  project                                   = "${var.project}-nomad-ec2"
  consul_server_count                       = var.nomad_consul_server_count
  key_name                                  = var.key_name
  ssh_public_key                            = tls_private_key.ssh_key.public_key_openssh
  consul_datacenter                         = var.nomad_consul_datacenter
  consul_version                            = var.consul_version
  consul_server_instance_type               = var.nomad_consul_server_instance_type
  nomad_region                              = var.nomad_region
  nomad_datacenter                          = var.nomad_datacenter
  nomad_client_instance_type                = var.nomad_client_instance_type
  client_groups                             = var.nomad_client_groups
  consul_primary_datacenter                 = var.consul_primary_datacenter
  consul_primary_addr                       = module.consul-eks.consul_server_ip
  datadog_api_key                           = var.datadog_api_key
  enable_streaming_servers                  = var.nomad_enable_streaming_servers
  enable_streaming_clients                  = var.nomad_enable_streaming_clients
  nomad_server_count                        = var.nomad_server_count
  nomad_server_instance_type                = var.nomad_server_instance_type
  consul_http_max_conns_per_client          = var.consul_http_max_conns_per_client
  consul_server_log_level                   = var.nomad_consul_server_log_level
  consul_client_log_level                   = var.nomad_consul_client_log_level
  consul_enable_ui_elb                      = var.nomad_consul_enable_ui_elb
  nomad_server_log_level                    = var.nomad_server_log_level
  nomad_client_log_level                    = var.nomad_client_log_level
  nomad_envoy_image                         = var.nomad_envoy_image
  nomad_version                             = var.nomad_version
  consul_download_url                       = var.nomad_consul_download_url
  nomad_envoy_log_level                     = var.nomad_envoy_log_level
  consul_tls_ca_cert_pem                    = tls_self_signed_cert.ca_cert.cert_pem
  consul_tls_server_cert_pem                = tls_locally_signed_cert.secondary_dc_server_cert.cert_pem
  consul_tls_server_key_pem                 = tls_private_key.secondary_dc_server_key.private_key_pem
  consul_gossip_encryption_key              = random_id.consul_gossip_encrypt.hex
  nomad_scheduler_algorithm                 = var.nomad_scheduler_algorithm
  consul_mount_ssd_volume                   = var.nomad_consul_mount_ssd_volume
  nomad_mount_ssd_volume                    = var.nomad_server_mount_ssd_volume
  nomad_client_random_startup_wait_time_max = var.nomad_client_random_startup_wait_time_max
  consul_gateway_instance_type              = var.nomad_consul_gateway_instance_type
}

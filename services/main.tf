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

data "terraform_remote_state" "infrastructure" {
  backend = "remote"

  config = {
    organization = "YOUR_TERRAFORM_CLOUD_ORGANIZATION_NAME_HERE"
    workspaces = {
      name = "consul-global-scale-benchmark-infrastructure"
    }
  }
}

## Consul Provider ##
provider "consul" {
  address    = data.terraform_remote_state.infrastructure.outputs.consul_eks_server_elb_dns
  datacenter = data.terraform_remote_state.infrastructure.outputs.consul_primary_datacenter
}

# The proxy defaults need to be set after server deployment
# using the Consul API.
resource "consul_config_entry" "proxy-defaults" {
  name = "global"
  kind = "proxy-defaults"

  config_json = jsonencode({
    Config = {
      "envoy_prometheus_bind_addr" = "0.0.0.0:9102",
      "envoy_stats_bind_addr"      = "0.0.0.0:9105",
      "protocol"                   = "http"
    }

    MeshGateway = {
      "mode" = "local"
    }
  })
}

# Create a key for consul agent shutdown to test gossip between nodes on Nomad.
resource "consul_keys" "consul-shutdown" {
  datacenter = data.terraform_remote_state.infrastructure.outputs.nomad_consul_datacenter

  key {
    path  = "consul-scalability-challenge/consul-shutdown-value"
    value = "0"
  }
}


## Kubernetes ##
## Kubernetes provider settings ##
data "aws_eks_cluster" "cluster_1" {
  name = data.terraform_remote_state.infrastructure.outputs.kubernetes_cluster_ids[0]
}

data "aws_eks_cluster_auth" "cluster_1" {
  name = data.terraform_remote_state.infrastructure.outputs.kubernetes_cluster_ids[0]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_1.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_1.token
  version                = "~> 1.10"

  alias = "cluster-1"
}

module "kubernetes_cluster_services_cluster_1" {
  source = "./kubernetes"

  providers = {
    kubernetes = kubernetes.cluster-1
  }

  service_count                                      = var.eks_service_count
  tier_1_service_instance_count                      = var.eks_tier_1_service_instance_count
  tier_2_service_instance_count                      = var.eks_tier_2_service_instance_count
  tier_3_service_instance_count                      = var.eks_tier_3_service_instance_count
  tier_2_traffic_redirect                            = var.tier_2_traffic_redirect
  tier_1_tier_2_service_api_upstream                 = var.tier_1_tier_2_service_api_upstream
  tier_1_tier_2_tier_3_service_hey_cross_dc_upstream = var.tier_1_tier_2_tier_3_service_hey_cross_dc_upstream
  cluster_name                                       = "cluster-1"
}

## Nomad ##
provider "nomad" {
  address = data.terraform_remote_state.infrastructure.outputs.nomad_ec2_server_elb_http_address
  region  = var.nomad_region
}

module "nomad_cluster_services" {
  source = "./nomad"

  ## 5 services (service count) for 3 nodes (5 services per node with c5.xlarge)
  ##### 15 services in total
  service_count                                      = var.nomad_service_count
  tier_1_service_instance_count                      = var.nomad_tier_1_service_instance_count
  tier_2_service_instance_count                      = var.nomad_tier_2_service_instance_count
  tier_3_service_instance_count                      = var.nomad_tier_3_service_instance_count
  tier_2_traffic_redirect                            = var.tier_2_traffic_redirect
  nomad_region                                       = var.nomad_region
  nomad_datacenter                                   = var.nomad_datacenter
  tier_1_tier_2_tier_3_service_api_cross_dc_upstream = var.tier_1_tier_2_tier_3_service_api_cross_dc_upstream
}

module "eks_loadgenerator" {
  source = "./loadgenerator"

  count = var.eks_enable_loadgenerator ? 1 : 0

  region                             = var.region
  project                            = "csc"
  vpc_id                             = data.terraform_remote_state.infrastructure.outputs.eks_vpc_id
  loadgenerator_asg_min_size         = var.eks_loadgenerator_asg_min_size
  loadgenerator_asg_max_size         = var.eks_loadgenerator_asg_max_size
  loadgenerator_asg_desired_capacity = var.eks_loadgenerator_asg_desired_capacity
  subnet_ids                         = data.terraform_remote_state.infrastructure.outputs.eks_subnet_ids
  key_name                           = var.key_name
  datadog_api_key                    = var.datadog_api_key
  consul_version                     = data.terraform_remote_state.infrastructure.outputs.eks_consul_version
  consul_datacenter                  = data.terraform_remote_state.infrastructure.outputs.eks_consul_datacenter
  retry_join_tag                     = data.terraform_remote_state.infrastructure.outputs.eks_consul_retry_join_tag
  loadgenerator_instance_type        = var.eks_loadgenerator_instance_type
  qps                                = var.eks_loadgenerator_qps
  concurrency                        = var.eks_loadgenerator_concurrency
  consul_http_max_conns_per_client   = var.consul_http_max_conns_per_client
  consul_download_url                = var.eks_loadgenerator_consul_download_url
  consul_gossip_encryption_key       = data.terraform_remote_state.infrastructure.outputs.consul_gossip_encryption_key
  consul_tls_ca_cert_pem             = data.terraform_remote_state.infrastructure.outputs.consul_tls_ca_cert_pem
}

module "nomad_loadgenerator" {
  source = "./loadgenerator"

  providers = {
    aws = aws.use1
  }

  count = var.nomad_enable_loadgenerator ? 1 : 0

  region                             = "us-east-1"
  project                            = "csc"
  vpc_id                             = data.terraform_remote_state.infrastructure.outputs.nomad_vpc_id
  loadgenerator_asg_min_size         = var.nomad_loadgenerator_asg_min_size
  loadgenerator_asg_max_size         = var.nomad_loadgenerator_asg_max_size
  loadgenerator_asg_desired_capacity = var.nomad_loadgenerator_asg_desired_capacity
  subnet_ids                         = data.terraform_remote_state.infrastructure.outputs.nomad_subnet_ids
  key_name                           = var.key_name
  datadog_api_key                    = var.datadog_api_key
  consul_version                     = data.terraform_remote_state.infrastructure.outputs.nomad_consul_version
  consul_datacenter                  = data.terraform_remote_state.infrastructure.outputs.nomad_consul_datacenter
  retry_join_tag                     = data.terraform_remote_state.infrastructure.outputs.nomad_consul_retry_join_tag
  loadgenerator_instance_type        = var.nomad_loadgenerator_instance_type
  qps                                = var.nomad_loadgenerator_qps
  concurrency                        = var.nomad_loadgenerator_concurrency
  consul_http_max_conns_per_client   = var.consul_http_max_conns_per_client
  consul_download_url                = var.nomad_loadgenerator_consul_download_url
  consul_gossip_encryption_key       = data.terraform_remote_state.infrastructure.outputs.consul_gossip_encryption_key
  consul_tls_ca_cert_pem             = data.terraform_remote_state.infrastructure.outputs.consul_tls_ca_cert_pem
}

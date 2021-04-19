variable "region" {
  default = "us-west-2"
}

variable "key_name" {
}

variable "datadog_api_key" {
  default = ""
}

variable "tier_2_traffic_redirect" {
  default = false
}

## EKS Cluster

variable "eks_service_count" {
  default = 1
}

variable "eks_tier_1_service_instance_count" {
}

variable "eks_tier_2_service_instance_count" {
}

variable "eks_tier_3_service_instance_count" {
}

variable "tier_2_to_tier_3_intention_deny" {
  default = false
}

variable "tier_1_tier_2_service_api_upstream" {
  default = false
}

variable "tier_1_tier_2_tier_3_service_hey_cross_dc_upstream" {
  default = false
}

variable "eks_loadgenerator_asg_min_size" {
  default = 0
}

variable "eks_loadgenerator_asg_max_size" {
  default = 0
}

variable "eks_loadgenerator_asg_desired_capacity" {
  default = 0
}

variable "eks_loadgenerator_instance_type" {
  default = "c5.large"
}

variable "eks_loadgenerator_qps" {
  default = 100
}

variable "eks_loadgenerator_concurrency" {
  default = 5
}

variable "eks_enable_loadgenerator" {
  default = true
}

variable "eks_loadgenerator_consul_download_url" {
}

## Nomad Cluster

variable "nomad_region" {
  default = "global"
}

variable "nomad_datacenter" {
  default = "dc1"
}

variable "nomad_service_count" {
  default = 1
}

variable "nomad_tier_1_service_instance_count" {
}

variable "nomad_tier_2_service_instance_count" {
}

variable "nomad_tier_3_service_instance_count" {
}

variable "tier_1_to_tier_2_intention_deny" {
  default = false
}

variable "nomad_loadgenerator_asg_min_size" {
  default = 0
}

variable "nomad_loadgenerator_asg_max_size" {
  default = 0
}

variable "nomad_loadgenerator_asg_desired_capacity" {
  default = 0
}

variable "nomad_loadgenerator_instance_type" {
  default = "c5.large"
}

variable "nomad_loadgenerator_qps" {
  default = 50
}

variable "nomad_loadgenerator_concurrency" {
  default = 2
}

variable "nomad_enable_loadgenerator" {
  default = true
}

variable "tier_1_tier_2_tier_3_service_api_cross_dc_upstream" {
  default = false
}

variable "nomad_loadgenerator_consul_download_url" {
}

## General loagenerator settings

variable "consul_http_max_conns_per_client" {
  default = 200
}

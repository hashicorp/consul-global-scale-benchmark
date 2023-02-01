# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "ami_id" {
}

variable "iam_instance_profile" {
}

variable "nomad_server_count" {
  default = 3
}

variable "nomad_server_instance_type" {
  default = "c5.large"
}

variable "nomad_region" {
  default = "global"
}

variable "nomad_datacenter" {
  default = "dc1"
}

variable "nomad_version" {
  default = "0.12.3"
}

variable "key_name" {
}

variable "retry_join_tag" {
  default = "consul"
}

variable "vpc_id" {
}

variable "subnet_ids" {
  default = []
}

variable "consul_datacenter" {
  default = "dc1"
}

variable "consul_version" {
  default = "1.9.5"
}

variable "region" {
  default = "us-west-2"
}

variable "project" {
  default = "consul-scale"
}

variable "nomad_client_instance_type" {
  default = "c5.large"
}

variable "availability_zones" {
  default = []
}

variable "asg_min_size" {
  default = 5
}

variable "asg_max_size" {
  default = 10
}

variable "asg_desired_capacity" {
  default = 5
}

variable "client_groups" {
  default = []
}

variable "consul_gateway_security_group_id" {
}

variable "datadog_api_key" {
}

variable "nomad_envoy_image" {
}

variable "consul_cache_use_streaming_backend" {
  default = false
}

variable "consul_http_config_use_cache" {
  default = false
}

variable "consul_dns_config_use_cache" {
  default = false
}

variable "consul_http_max_conns_per_client" {
  default = 200
}

variable "consul_client_log_level" {
  default = "DEBUG"
}

variable "nomad_server_log_level" {
  default = "INFO"
}

variable "nomad_client_log_level" {
  default = "INFO"
}

variable "consul_download_url" {
  type = string
}

variable "nomad_envoy_log_level" {
  default = "debug"
}

variable "consul_tls_ca_cert_pem" {
}

variable "consul_gossip_encryption_key" {
}

variable "nomad_scheduler_algorithm" {
  default = "binpack"
}

variable "mount_ssd_volume" {
}

variable "nomad_client_random_startup_wait_time_max" {
}
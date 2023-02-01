# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  default = "us-west-2"
}

variable "project" {
  default = "csc"
}

variable "consul_primary_datacenter" {
  default = "dc1"
}

variable "consul_version" {
  default = "1.9.5"
}

variable "key_name" {
}

variable "datadog_api_key" {
  default = ""
}

variable "consul_http_max_conns_per_client" {
  default = 200
}

variable "enable_streaming" {
  default = false
}

## EKS Cluster

variable "eks_consul_server_count" {
  default = 3
}

variable "eks_consul_datacenter" {
  default = "dc1"
}

variable "eks_consul_server_instance_type" {
  default = "c5.xlarge"
}

variable "worker_group_asg" {
}

variable "eks_enable_streaming_servers" {
  default = true
}

variable "eks_enable_streaming_clients" {
  default = true
}

variable "eks_consul_global_image" {
  default = "consul"
}

variable "eks_consul_envoy_global_image" {
  default = "envoy"
}

variable "eks_consul_envoy_global_image_version" {
  default = ""
}

variable "eks_consul_k8s_global_image" {
}

variable "eks_consul_client_log_level" {
  default = "INFO"
}

variable "eks_consul_server_log_level" {
  default = "INFO"
}

variable "eks_consul_enable_ui_elb" {
  default = true
}

variable "eks_consul_download_url" {
  default = ""
}

variable "eks_consul_envoy_log_level" {
}

variable "eks_consul_helm_chart_version" {
}

variable "eks_consul_mount_ssd_volume" {
}

## Nomad Cluster

variable "nomad_server_count" {
  default = 3
}

variable "nomad_server_instance_type" {
  default = "c5.large"
}


variable "nomad_consul_server_count" {
  default = 3
}

variable "nomad_consul_datacenter" {
  default = "dc2"
}

variable "nomad_consul_server_instance_type" {
  default = "c5.xlarge"
}

variable "nomad_region" {
  default = "global"
}

variable "nomad_datacenter" {
  default = "dc1"
}

variable "nomad_client_instance_type" {
  default = "c5.xlarge"
}

variable "nomad_client_groups" {
  default = []
}

variable "nomad_enable_streaming_servers" {
  default = true
}

variable "nomad_enable_streaming_clients" {
  default = true
}

variable "nomad_envoy_image" {
  default = "envoyproxy/envoy:v1.16.0@sha256:9e72bbba48041223ccf79ba81754b1bd84a67c6a1db8a9dbff77ea6fc1cb04ea"
}

variable "nomad_consul_server_log_level" {
  default = "DEBUG"
}

variable "nomad_consul_client_log_level" {
  default = "DEBUG"
}

variable "nomad_server_log_level" {
  default = "INFO"
}

variable "nomad_client_log_level" {
  default = "INFO"
}

variable "nomad_consul_enable_ui_elb" {
  default = true
}

variable "nomad_version" {
  default = "1.0.2"
}

variable "nomad_consul_download_url" {
  default = ""
}

variable "nomad_envoy_log_level" {
}

variable "nomad_scheduler_algorithm" {
}

variable "nomad_consul_mount_ssd_volume" {
}

variable "nomad_server_mount_ssd_volume" {
}

variable "nomad_client_random_startup_wait_time_max" {
}

variable "nomad_consul_gateway_instance_type" {
}
variable "region" {
  default = "us-west-2"
}

variable "project" {
  default = "consul-scale"
}

variable "consul_datacenter" {
  default = "dc1"
}

variable "consul_version" {
}

variable "consul_primary_datacenter" {
}

variable "consul_primary_addr" {
  default = ""
}

variable "consul_server_instance_type" {
  default = "c5.large"
}

variable "retry_join_tag" {
  default = "consul-eks"
}

variable "consul_server_count" {
  default = 3
}

variable "key_name" {
}

variable "ssh_public_key" {
}

variable "datadog_api_key" {
}

variable "consul_global_image" {
  default = "consul"
}

variable "consul_k8s_global_image" {
  default = "hashicorp/consul-k8s"
}

variable "consul_envoy_global_image" {
  default = "envoyproxy/envoy"
}

variable "consul_envoy_global_image_version" {
  default = "v1.16.0"
}

variable "consul_global_k8s_image" {
  default = "hashicorp/consul-k8s"
}

variable "consul_client_log_level" {
  default = "INFO"
}

variable "consul_server_log_level" {
  default = "DEBUG"
}

variable "consul_enable_ui_elb" {
  default = true
}

variable "worker_group_asg" {
  default = {
    asg_desired_capacity = 3
    instance_type        = "c5.large"
  }
}

variable "enable_streaming_servers" {
  default = false
}

variable "enable_streaming_clients" {
  default = false
}

variable "consul_download_url" {
}

variable "consul_envoy_log_level" {
}

variable "consul_tls_ca_cert_pem" {
}

variable "consul_tls_server_cert_pem" {
}

variable "consul_tls_server_key_pem" {
}

variable "consul_gossip_encryption_key" {
}

variable "consul_helm_chart_version" {
}

variable "consul_mount_ssd_volume" {
}

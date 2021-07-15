variable "worker_group_asg" {
}

variable "consul_global_image" {
}

variable "consul_k8s_global_image" {
}

variable "consul_envoy_global_image" {
}

variable "consul_envoy_global_image_version" {
}

variable "consul_datacenter" {
}

variable "region" {
}

variable "retry_join_tag" {
}

variable "consul_primary_datacenter" {
}

variable "enable_streaming_clients" {
}

variable "consul_client_log_level" {
}

variable "consul_global_k8s_image" {
}

variable "datadog_api_key" {
}

variable "consul_envoy_log_level" {
  default = "debug"
}

variable "consul_tls_ca_cert_pem" {
}

variable "consul_gossip_encryption_key" {
}

variable "consul_helm_chart_version" {
  default = "0.28.0"
}

variable "consul_version" {
}
variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "project" {
  default = "consul-scale"
}

variable "vpc_id" {
  default = ""
}

variable "subnet_ids" {
  default = []
}

variable "instance_type" {
  default = "c5.large"
}

variable "consul_server_count" {
  default = 3
}

variable "consul_version" {
  default = "1.9.5"
}

variable "consul_datacenter" {
  default = "dc1"
}

variable "consul_primary_datacenter" {
  default = "dc1"
}

variable "consul_primary_addr" {
  default = ""
}

variable "retry_join_tag" {
  default = "consul"
}

variable "iam_instance_profile" {
  default = ""
}

variable "ami_id" {
  default = ""
}

variable "region" {
  default = "us-west-2"
}

variable "consul_client_ingress_security_groups" {
  default = []
}

variable "datadog_api_key" {
  default = ""
}

variable "enable_streaming" {
  default = false
}

variable "consul_log_level" {
  default = "INFO"
}

variable "enable_ui_elb" {
  default = true
}

variable "consul_download_url" {
  type = string
}

variable "tls_ca_cert_pem" {
  type = string
}

variable "tls_server_cert_pem" {
  type = string
}

variable "tls_server_key_pem" {
  type = string
}

variable "gossip_encryption_key" {
  type = string
}

variable "mount_ssd_volume" {
  default = false
}
variable "vpc_id" {
  default = ""
}

variable "project" {
  default = "consul-scale"
}

variable "region" {
  default = "us-west-2"
}

variable "loadgenerator_asg_min_size" {
  default = 1
}

variable "loadgenerator_asg_max_size" {
  default = 10
}

variable "loadgenerator_asg_desired_capacity" {
  default = 1
}

variable "subnet_ids" {
  default = []
}

variable "key_name" {
  default = ""
}

variable "loadgenerator_instance_type" {
  default = "t2.medium"
}

variable "datadog_api_key" {
  default = ""
}

variable "qps" {
  default = 2
}

variable "concurrency" {
  default = 1
}

variable "consul_datacenter" {
  default = "dc1"
}

variable "consul_version" {
  default = "1.9.5"
}

variable "consul_http_max_conns_per_client" {
  default = 200
}

variable "retry_join_tag" {
}

variable "consul_download_url" {
}

variable "consul_gossip_encryption_key" {
}

variable "consul_tls_ca_cert_pem" {
}
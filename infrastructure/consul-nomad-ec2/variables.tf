variable "region" {
  default = "us-west-2"
}

variable "project" {
  default = "consul-scale"
}

variable "nomad_client_instance_type" {
  default = "c5.large"
}

variable "nomad_region" {
  default = "global"
}

variable "nomad_datacenter" {
  default = "dc1"
}

variable "nomad_server_count" {
  default = 3
}

variable "nomad_server_instance_type" {
  default = "c5.large"
}

variable "asg_min_size" {
  default = 3
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

variable "consul_datacenter" {
  default = "dc1"
}

variable "consul_primary_datacenter" {
  default = ""
}

variable "consul_primary_addr" {
  default = ""
}

variable "consul_server_instance_type" {
  default = "c5.large"
}

variable "consul_gateway_count" {
  default = 2
}

variable "consul_http_max_conns_per_client" {
  default = 200
}

variable "consul_gateway_instance_type" {
  default = "t3.large"
}

variable "retry_join_tag" {
  default = "consul-nomad-ec2"
}

variable "consul_server_count" {
  default = 3
}

variable "consul_version" {
}

variable "envoy_version" {
  # You can use the following command to list all versions
  # for envoy on the gateway servers: sudo apt list -a getenvoy-envoy
  default = "1.13.1.p0.gb67c140-1p58.g95766ea"
}

variable "key_name" {
}

variable "ssh_public_key" {
}

variable "datadog_api_key" {
  default = ""
}

variable "enable_streaming_servers" {
  default = false
}

variable "enable_streaming_clients" {
  default = false
}

variable "consul_server_log_level" {
  default = "DEBUG"
}

variable "consul_client_log_level" {
  default = "DEBUG"
}

variable "consul_enable_ui_elb" {
  default = false
}

variable "nomad_server_log_level" {
  default = "INFO"
}

variable "nomad_client_log_level" {
  default = "INFO"
}

variable "nomad_envoy_image" {
}

variable "nomad_version" {
  default = "0.12.3"
}

variable "consul_download_url" {
}

variable "nomad_envoy_log_level" {
}

variable "consul_tls_ca_cert_pem" {
}

variable "consul_tls_server_cert_pem" {
}

variable "consul_tls_server_key_pem" {
}

variable "consul_gossip_encryption_key" {
}

variable "nomad_scheduler_algorithm" {
}

variable "consul_mount_ssd_volume" {
}

variable "nomad_mount_ssd_volume" {
}

variable "nomad_client_random_startup_wait_time_max" {
}
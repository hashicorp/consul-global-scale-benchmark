# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_ids" {
  value = module.vpc.public_subnets
}

output "consul_server_ips" {
  value = module.consul_server.consul_server_ips
}

output "nomad_server_ips" {
  value = module.nomad_cluster.nomad_server_ips
}

output "nomad_client_asg_name" {
  value = module.nomad_cluster.nomad_client_asg_name
}

output "nomad_http_elb_address" {
  value = module.nomad_cluster.nomad_http_elb_address
}

output "consul_gateway_ips" {
  value = aws_instance.consul_gateway.*.public_ip
}

output "consul_datacenter" {
  value = var.consul_datacenter
}

output "consul_version" {
  value = var.consul_version
}

output "consul_retry_join_tag" {
  value = var.retry_join_tag
}

output "consul_elb" {
  value = module.consul_server.consul_elb
}
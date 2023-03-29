# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_endpoints" {
  description = "Endpoints for EKS control planes."
  value = [
    module.eks-cluster-1.cluster_endpoint,
  ]
}

output "kubeconfig_filenames" {
  description = "The filenames of the generated kubectl configs."
  value = [
    module.eks-cluster-1.kubeconfig_filename,
  ]
}

output "cluster_ids" {
  value = [
    module.eks-cluster-1.cluster_id,
  ]
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "consul_server_ip" {
  value = module.consul_server.consul_server_ip
}

output "consul_elb" {
  value = module.consul_server.consul_elb
}

output "consul_server_ips" {
  value = module.consul_server.consul_server_ips
}

# VPC specific outputs

output "subnet_ids" {
  value = module.vpc.public_subnets
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "consul_version" {
  value = var.consul_version
}

output "consul_datacenter" {
  value = var.consul_datacenter
}

output "consul_retry_join_tag" {
  value = var.retry_join_tag
}
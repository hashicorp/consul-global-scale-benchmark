# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "consul_eks_server_elb_dns" {
  value = module.consul-eks.consul_elb
}

output "consul_nomad_server_elb_dns" {
  value = module.consul-nomad-ec2.consul_elb
}

output "consul_eks_consul_server_ips" {
  value = module.consul-eks.consul_server_ips
}

output "consul_nomad_ec2_server_ips" {
  value = module.consul-nomad-ec2.consul_server_ips
}

output "consul_primary_datacenter" {
  value = var.consul_primary_datacenter
}

output "consul_gossip_encryption_key" {
  value = random_id.consul_gossip_encrypt.hex
}

output "consul_tls_ca_cert_pem" {
  value = tls_self_signed_cert.ca_cert.cert_pem
}

output "nomad_ec2_server_elb_http_address" {
  value = "http://${module.consul-nomad-ec2.nomad_http_elb_address}"
}

output "nomad_ec2_server_ips" {
  value = module.consul-nomad-ec2.nomad_server_ips
}

output "nomad_ec2_gateway_ips" {
  value = module.consul-nomad-ec2.consul_gateway_ips
}

output "kubeconfig_filenames" {
  value = [
    for filename in module.consul-eks.kubeconfig_filenames :
    "export KUBECONFIG=${filename}"
  ]
}

output "kubeconfig_configure" {
  value = "export KUBECONFIG=${join(":", module.consul-eks.kubeconfig_filenames)}:$KUBECONFIG"
}

output "kubernetes_cluster_ids" {
  value = module.consul-eks.cluster_ids
}

output "ssh_key" {
  value = "${path.module}/.ssh/id_rsa"
}

## VPC related variables for EKS

output "eks_vpc_id" {
  value = module.consul-eks.vpc_id
}

output "eks_subnet_ids" {
  value = module.consul-eks.subnet_ids
}

## Consul related variables for EKS

output "eks_consul_version" {
  value = module.consul-eks.consul_version
}

output "eks_consul_datacenter" {
  value = module.consul-eks.consul_datacenter
}

output "eks_consul_retry_join_tag" {
  value = module.consul-eks.consul_retry_join_tag
}

## VPC related variables for Nomad

output "nomad_vpc_id" {
  value = module.consul-nomad-ec2.vpc_id
}

output "nomad_subnet_ids" {
  value = module.consul-nomad-ec2.subnet_ids
}

## Consul related variables for Nomad

output "nomad_consul_version" {
  value = module.consul-nomad-ec2.consul_version
}

output "nomad_consul_datacenter" {
  value = module.consul-nomad-ec2.consul_datacenter
}

output "nomad_consul_retry_join_tag" {
  value = module.consul-nomad-ec2.consul_retry_join_tag
}

## Test data related

output "eks_consul_services_total" {
  value = "ssh ubuntu@$(terraform output -json consul_eks_consul_server_ips | jq -r '.[0]') \"curl -s http://127.0.0.1:8500/v1/catalog/services?dc=${var.eks_consul_datacenter} | jq -r '. | keys | .[]' | wc -l\""
}

output "eks_consul_tier_services" {
  value = "ssh ubuntu@$(terraform output -json consul_eks_consul_server_ips | jq -r '.[0]') \"curl -s http://127.0.0.1:8500/v1/catalog/services?dc=${var.eks_consul_datacenter} | jq -r '. | keys | .[]' | grep -v 'sidecar-proxy' | grep -v 'consul' | grep -v 'nomad' | wc -l\""
}

output "nomad_consul_services_total" {
  value = "ssh ubuntu@$(terraform output -json consul_eks_consul_server_ips | jq -r '.[0]') \"curl -s http://127.0.0.1:8500/v1/catalog/services?dc=${var.nomad_consul_datacenter} | jq -r '. | keys | .[]' | wc -l\""
}

output "nomad_consul_tier_services" {
  value = "ssh ubuntu@$(terraform output -json consul_eks_consul_server_ips | jq -r '.[0]') \"curl -s http://127.0.0.1:8500/v1/catalog/services?dc=${var.nomad_consul_datacenter} | jq -r '. | keys | .[]' | grep -v 'sidecar-proxy' | grep -v 'consul' | grep -v 'nomad' | wc -l\""
}


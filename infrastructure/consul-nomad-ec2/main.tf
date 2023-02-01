# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

##########################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = var.ssh_public_key
}

# Create an IAM role for the auto-join
resource "aws_iam_role" "consul-retry-join" {
  name = "${var.project}-consul-retry-join"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create an IAM policy for allowing instances that are running
# Consul agent can use to list the consul servers.
resource "aws_iam_policy" "consul-retry-join" {
  name        = "${var.project}-consul-retry-join"
  description = "Allows Consul nodes to describe instances for joining."

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach the policy
resource "aws_iam_policy_attachment" "consul-retry-join" {
  name       = "${var.project}-consul-retry-join"
  roles      = [aws_iam_role.consul-retry-join.name]
  policy_arn = aws_iam_policy.consul-retry-join.arn
}

# Create the instance profile
resource "aws_iam_instance_profile" "consul-retry-join" {
  name = "${var.project}-consul-retry-join"
  role = aws_iam_role.consul-retry-join.name
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.6"

  name                 = "${var.project}-consul-nomad"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.192.0/19", "172.16.224.0/19"]
  public_subnets       = ["172.16.0.0/18", "172.16.64.0/18", "172.16.128.0/18"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

module "consul_server" {
  source = "../consul-server-ec2"

  region                    = var.region
  project                   = var.project
  key_name                  = aws_key_pair.key_pair.key_name
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.public_subnets
  consul_server_count       = var.consul_server_count
  consul_datacenter         = var.consul_datacenter
  consul_version            = var.consul_version
  instance_type             = var.consul_server_instance_type
  iam_instance_profile      = aws_iam_instance_profile.consul-retry-join.name
  ami_id                    = data.aws_ami.ubuntu.id
  consul_primary_datacenter = var.consul_primary_datacenter
  consul_primary_addr       = var.consul_primary_addr
  retry_join_tag            = var.retry_join_tag
  datadog_api_key           = var.datadog_api_key
  enable_streaming          = var.enable_streaming_servers
  consul_log_level          = var.consul_server_log_level
  enable_ui_elb             = var.consul_enable_ui_elb
  consul_download_url       = var.consul_download_url
  tls_ca_cert_pem           = var.consul_tls_ca_cert_pem
  tls_server_cert_pem       = var.consul_tls_server_cert_pem
  tls_server_key_pem        = var.consul_tls_server_key_pem
  gossip_encryption_key     = var.consul_gossip_encryption_key
  mount_ssd_volume          = var.consul_mount_ssd_volume
}

module "nomad_cluster" {
  depends_on = [module.consul_server.aws_instance]
  source     = "./nomad-cluster"

  region                                    = var.region
  project                                   = var.project
  key_name                                  = aws_key_pair.key_pair.key_name
  vpc_id                                    = module.vpc.vpc_id
  subnet_ids                                = module.vpc.public_subnets
  nomad_server_count                        = var.nomad_server_count
  nomad_server_instance_type                = var.nomad_server_instance_type
  nomad_client_instance_type                = var.nomad_client_instance_type
  asg_min_size                              = var.asg_min_size
  asg_max_size                              = var.asg_max_size
  asg_desired_capacity                      = var.asg_desired_capacity
  client_groups                             = var.client_groups
  consul_datacenter                         = var.consul_datacenter
  consul_gateway_security_group_id          = aws_security_group.consul-gateway.id
  ami_id                                    = data.aws_ami.ubuntu.id
  iam_instance_profile                      = aws_iam_instance_profile.consul-retry-join.name
  retry_join_tag                            = var.retry_join_tag
  datadog_api_key                           = var.datadog_api_key
  consul_cache_use_streaming_backend        = var.enable_streaming_clients
  consul_http_config_use_cache              = var.enable_streaming_clients
  consul_dns_config_use_cache               = var.enable_streaming_clients
  consul_http_max_conns_per_client          = var.consul_http_max_conns_per_client
  consul_client_log_level                   = var.consul_client_log_level
  nomad_server_log_level                    = var.nomad_server_log_level
  nomad_client_log_level                    = var.nomad_client_log_level
  nomad_envoy_image                         = var.nomad_envoy_image
  nomad_version                             = var.nomad_version
  consul_download_url                       = var.consul_download_url
  nomad_envoy_log_level                     = var.nomad_envoy_log_level
  consul_tls_ca_cert_pem                    = var.consul_tls_ca_cert_pem
  consul_gossip_encryption_key              = var.consul_gossip_encryption_key
  nomad_scheduler_algorithm                 = var.nomad_scheduler_algorithm
  mount_ssd_volume                          = var.nomad_mount_ssd_volume
  nomad_client_random_startup_wait_time_max = var.nomad_client_random_startup_wait_time_max
}


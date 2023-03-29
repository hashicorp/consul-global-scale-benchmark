# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

data "aws_availability_zones" "available" {
}

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


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.6"

  name                 = "${var.project}-consul-eks"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.192.0/19", "172.16.224.0/19"]
  public_subnets       = ["172.16.0.0/18", "172.16.64.0/18", "172.16.128.0/18"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.project}-cluster-1" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.project}-cluster-1" = "shared"
    "kubernetes.io/role/elb"                         = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.project}-cluster-1" = "shared"
    "kubernetes.io/role/internal-elb"                = "1"
  }
}

resource "aws_security_group" "consul-eks-allow-all-vpc" {
  name        = "consul-eks-allow-all-vpc"
  description = "Allow all nodes to talk to any other node on consul specific ports in the vpc"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8300
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8300
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8125
    to_port     = 8125
    protocol    = "udp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8126
    to_port     = 8126
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  # ingress from load generator into tier-1 services
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  # ingress on consul connect proxy port between multiple clusters if needed
  ingress {
    from_port   = 20000
    to_port     = 20000
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Configuration for Consul servers on EC2
############################################

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


module "consul_server" {
  source = "../consul-server-ec2"

  region                                = var.region
  project                               = var.project
  key_name                              = aws_key_pair.key_pair.key_name
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = module.vpc.public_subnets
  consul_server_count                   = var.consul_server_count
  consul_datacenter                     = var.consul_datacenter
  consul_version                        = var.consul_version
  instance_type                         = var.consul_server_instance_type
  iam_instance_profile                  = aws_iam_instance_profile.consul-retry-join.name
  ami_id                                = data.aws_ami.ubuntu.id
  consul_primary_datacenter             = var.consul_primary_datacenter
  consul_primary_addr                   = var.consul_primary_addr
  retry_join_tag                        = var.retry_join_tag
  consul_client_ingress_security_groups = [aws_security_group.consul-eks-allow-all-vpc.id]
  datadog_api_key                       = var.datadog_api_key
  enable_streaming                      = var.enable_streaming_servers
  enable_ui_elb                         = var.consul_enable_ui_elb
  consul_log_level                      = var.consul_server_log_level
  consul_download_url                   = var.consul_download_url
  tls_ca_cert_pem                       = var.consul_tls_ca_cert_pem
  tls_server_cert_pem                   = var.consul_tls_server_cert_pem
  tls_server_key_pem                    = var.consul_tls_server_key_pem
  gossip_encryption_key                 = var.consul_gossip_encryption_key
  mount_ssd_volume                      = var.consul_mount_ssd_volume
}

## EKS cluster auth and kubernetes provider for each cluster
# Each EKS cluster uses a module which enables us to have multiple EKS clusters if we like
data "aws_eks_cluster" "cluster_1" {
  name = module.eks-cluster-1.cluster_id
}

data "aws_eks_cluster_auth" "cluster_1" {
  name = module.eks-cluster-1.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_1.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_1.token
  version                = "~> 1.10"

  alias = "cluster-1"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster_1.endpoint
    token                  = data.aws_eks_cluster_auth.cluster_1.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_1.certificate_authority.0.data)
  }

  alias = "cluster-1"
}

# EKS clusters
module "eks-cluster-1" {

  providers = {
    kubernetes = kubernetes.cluster-1
  }

  source                      = "terraform-aws-modules/eks/aws"
  version                     = "v13.2.1"
  cluster_name                = "${var.project}-cluster-1"
  cluster_version             = "1.18"
  subnets                     = module.vpc.public_subnets
  workers_additional_policies = [aws_iam_policy.consul-retry-join.arn]

  tags = {
    Environment = "test"
    // Added to resolve issues when using depends_on with the eks module. https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1010#issuecomment-733307450
    ConsulServerIP = module.consul_server.consul_server_ip
  }

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "${var.project}-cluster-1"
      instance_type                 = lookup(var.worker_group_asg, "instance_type", "t2.micro")
      asg_desired_capacity          = lookup(var.worker_group_asg, "asg_desired_capacity", 3)
      asg_min_size                  = lookup(var.worker_group_asg, "asg_min_size", 3)
      asg_max_size                  = lookup(var.worker_group_asg, "asg_max_size", 3)
      additional_security_group_ids = [aws_security_group.consul-eks-allow-all-vpc.id]
    }
  ]
}

# Consul and Datadog helm charts
module "consul-datadog-cluster-1" {

  depends_on = [module.eks-cluster-1.workers_asg_arns]

  providers = {
    kubernetes = kubernetes.cluster-1
    helm       = helm.cluster-1
  }

  source                            = "./consul-datadog"
  worker_group_asg                  = var.worker_group_asg
  consul_global_image               = var.consul_global_image
  consul_k8s_global_image           = var.consul_k8s_global_image
  consul_envoy_global_image         = var.consul_envoy_global_image
  consul_envoy_global_image_version = var.consul_envoy_global_image_version
  consul_datacenter                 = var.consul_datacenter
  region                            = var.region
  retry_join_tag                    = var.retry_join_tag
  consul_primary_datacenter         = var.consul_primary_datacenter
  enable_streaming_clients          = var.enable_streaming_clients
  consul_client_log_level           = var.consul_client_log_level
  consul_global_k8s_image           = var.consul_global_k8s_image
  datadog_api_key                   = var.datadog_api_key
  consul_envoy_log_level            = var.consul_envoy_log_level
  consul_tls_ca_cert_pem            = var.consul_tls_ca_cert_pem
  consul_gossip_encryption_key      = var.consul_gossip_encryption_key
  consul_helm_chart_version         = var.consul_helm_chart_version
  consul_version                    = var.consul_version
}

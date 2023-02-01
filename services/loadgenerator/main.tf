# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

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

data "template_file" "loadgenerator" {
  template = <<EOF
${file("${path.module}/templates/loadgenerator.tpl")}
EOF
  vars = {
    datadog_api_key = var.datadog_api_key
    qps             = var.qps
    concurrency     = var.concurrency
    #url               = var.url
    consul_version                   = var.consul_version
    consul_datacenter                = var.consul_datacenter
    retry_join_tag                   = var.retry_join_tag
    consul_http_max_conns_per_client = var.consul_http_max_conns_per_client
    consul_download_url              = var.consul_download_url
    consul_gossip_encryption_key     = var.consul_gossip_encryption_key
  }
}

data "template_cloudinit_config" "loadgenerator_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<EOT
#!/bin/bash

mkdir -p /etc/consul/tls
sudo tee /etc/consul/tls/ca_cert.pem > /dev/null <<EOC
${var.consul_tls_ca_cert_pem}
EOC
EOT
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.loadgenerator.rendered
  }
}

# Create an IAM policy for allowing instances that are running
# the loadgenerator.
resource "aws_iam_policy" "loadgenerator" {
  name        = "${var.project}-${var.region}-loadgenerator"
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

# Create an IAM role
resource "aws_iam_role" "loadgenerator" {
  name = "${var.project}-${var.region}-loadgenerator"

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

# Attach the policy
resource "aws_iam_policy_attachment" "loadgenerator" {
  name       = "${var.project}-${var.region}-loadgenerator"
  roles      = [aws_iam_role.loadgenerator.name]
  policy_arn = aws_iam_policy.loadgenerator.arn
}

# Create the instance profile
resource "aws_iam_instance_profile" "loadgenerator" {
  name = "${var.project}-${var.region}-loadgenerator"
  role = aws_iam_role.loadgenerator.name
}

resource "aws_security_group" "loadgenerator" {
  name        = "${var.project}-${var.region}-loadgenerator"
  description = "loadgenerator security group rules"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    from_port   = 8126
    to_port     = 8126
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "loadgenerator" {
  launch_configuration = aws_launch_configuration.loadgenerator_launch_configuration.name

  name                = "${var.project}-loadgenerator-${var.region}"
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.loadgenerator_asg_min_size
  max_size         = var.loadgenerator_asg_max_size
  desired_capacity = var.loadgenerator_asg_desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = 300
  wait_for_capacity_timeout = "10m"

  tag {
    key                 = "Name"
    value               = "${var.project}-loadgenerator-${var.region}"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "loadgenerator_launch_configuration" {
  name_prefix      = "${var.project}-loadgenerator-${var.region}-"
  image_id         = data.aws_ami.ubuntu.id
  instance_type    = var.loadgenerator_instance_type
  user_data_base64 = data.template_cloudinit_config.loadgenerator_config.rendered

  iam_instance_profile = aws_iam_instance_profile.loadgenerator.name
  key_name             = var.key_name

  security_groups             = [aws_security_group.loadgenerator.id]
  associate_public_ip_address = true

  ebs_optimized = false

  root_block_device {
    volume_type           = "standard"
    volume_size           = 50
    delete_on_termination = true
  }

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}
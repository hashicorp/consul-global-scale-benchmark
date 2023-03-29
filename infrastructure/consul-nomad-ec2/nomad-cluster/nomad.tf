# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  client_group_count = length(var.client_groups)
  cloud_config_consul_kv_watch_file = <<-EOF
    #cloud-config
    ${jsonencode({
  write_files = [
    {
      path        = "/tmp/consul-template-kv-shutdown-watch.tpl"
      permissions = "0644"
      owner       = "root:root"
      encoding    = "b64"
      content     = filebase64("${path.module}/templates/consul-template-kv-shutdown-watch.tpl")
    },
  ]
})}
  EOF
}

data "template_file" "nomad_server" {
  count = var.nomad_server_count

  template = <<EOF
${file("${path.module}/templates/nomad-server.tpl")}
EOF
  vars = {
    nomad_server_count                 = var.nomad_server_count
    consul_version                     = var.consul_version
    nomad_version                      = var.nomad_version
    consul_datacenter                  = var.consul_datacenter
    nomad_datacenter                   = var.nomad_datacenter
    consul_client_log_level            = var.consul_client_log_level
    nomad_region                       = var.nomad_region
    retry_join_tag                     = var.retry_join_tag
    hostname                           = "nomad-server-${var.region}-${count.index + 1}"
    datadog_api_key                    = var.datadog_api_key
    consul_cache_use_streaming_backend = var.consul_cache_use_streaming_backend
    consul_http_config_use_cache       = var.consul_http_config_use_cache
    consul_dns_config_use_cache        = var.consul_dns_config_use_cache
    nomad_server_log_level             = var.nomad_server_log_level
    consul_download_url                = var.consul_download_url
    consul_gossip_encryption_key       = var.consul_gossip_encryption_key
    nomad_scheduler_algorithm          = var.nomad_scheduler_algorithm
    mount_ssd_volume                   = var.mount_ssd_volume
  }
}

data "template_cloudinit_config" "nomad_server_config" {
  count = var.nomad_server_count

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
    content      = element(data.template_file.nomad_server.*.rendered, count.index)
  }
}

data "template_file" "nomad_client" {
  template = <<EOF
${file("${path.module}/templates/nomad-client.tpl")}
EOF
  vars = {
    consul_version                            = var.consul_version
    nomad_version                             = var.nomad_version
    consul_datacenter                         = var.consul_datacenter
    nomad_datacenter                          = var.nomad_datacenter
    consul_client_log_level                   = var.consul_client_log_level
    nomad_region                              = var.nomad_region
    retry_join_tag                            = var.retry_join_tag
    datadog_api_key                           = var.datadog_api_key
    nomad_envoy_image                         = var.nomad_envoy_image
    consul_cache_use_streaming_backend        = var.consul_cache_use_streaming_backend
    consul_http_config_use_cache              = var.consul_http_config_use_cache
    consul_dns_config_use_cache               = var.consul_dns_config_use_cache
    consul_http_max_conns_per_client          = var.consul_http_max_conns_per_client
    nomad_client_log_level                    = var.nomad_client_log_level
    consul_download_url                       = var.consul_download_url
    nomad_envoy_log_level                     = var.nomad_envoy_log_level
    consul_gossip_encryption_key              = var.consul_gossip_encryption_key
    nomad_client_random_startup_wait_time_max = var.nomad_client_random_startup_wait_time_max
  }
}

data "template_cloudinit_config" "nomad_client_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content      = local.cloud_config_consul_kv_watch_file
  }


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
    content      = data.template_file.nomad_client.rendered
  }
}

resource "aws_security_group" "nomad-server" {
  name        = "nomad-server"
  description = "Allow Nomad servers to ingress and allow external HTTP access via the internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 4646
    to_port         = 4646
    protocol        = "tcp"
    security_groups = [aws_security_group.nomad-ui-elb.id]
  }

  ingress {
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nomad-client" {
  name        = "nomad-client"
  description = "Allow Nomad client to ingress and allow external HTTPS access via the internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 20000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.consul_gateway_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nomad-ui-elb" {
  name        = "nomad-ui-elb"
  description = "Allow ingress to access the Nomad UI."
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_elb" "nomad_ui" {
  name            = "nomad-ui-${var.region}-elb"
  subnets         = var.subnet_ids
  security_groups = [aws_security_group.nomad-ui-elb.id]

  listener {
    instance_port     = 4646
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:4646/v1/status/leader"
    interval            = 30
  }

  instances                 = aws_instance.nomad_server.*.id
  cross_zone_load_balancing = true
  idle_timeout              = 400
  connection_draining       = true

  tags = {
    Name = "nomad-ui-${var.region}-${var.project}-elb"
  }
}

resource "aws_instance" "nomad_server" {
  count                  = var.nomad_server_count
  instance_type          = var.nomad_server_instance_type
  ami                    = var.ami_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nomad-server.id]
  iam_instance_profile   = var.iam_instance_profile
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  user_data_base64       = element(data.template_cloudinit_config.nomad_server_config.*.rendered, count.index)
  tags = {
    "Name" = "nomad-server-${var.region}-${count.index + 1}"
  }

}

resource "aws_autoscaling_policy" "nomad_client_simple_scaling" {
  count = local.client_group_count

  name                   = "${var.project}-nomad-client-scaling-${count.index + 1}"
  cooldown               = 120
  scaling_adjustment     = 10
  adjustment_type        = "PercentChangeInCapacity"
  autoscaling_group_name = element(aws_autoscaling_group.nomad_client.*.name, count.index)
}

resource "aws_autoscaling_group" "nomad_client" {
  count = local.client_group_count

  launch_configuration = aws_launch_configuration.nomad_client_launch_configuration.name

  name                = "${var.project}-nomad-client-${var.region}-${count.index + 1}"
  vpc_zone_identifier = var.subnet_ids

  min_size         = lookup(var.client_groups[count.index], "asg_min_size", var.asg_min_size)
  max_size         = lookup(var.client_groups[count.index], "asg_max_size", var.asg_max_size)
  desired_capacity = lookup(var.client_groups[count.index], "asg_desired_capacity", var.asg_desired_capacity)

  health_check_type         = "EC2"
  health_check_grace_period = 300
  wait_for_capacity_timeout = 0

  tag {
    key                 = "Name"
    value               = "${var.project}-nomad-client-${var.region}-${count.index + 1}"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "nomad_client_launch_configuration" {
  name_prefix      = "${var.project}-nomad-client-${var.region}-"
  image_id         = var.ami_id
  instance_type    = var.nomad_client_instance_type
  user_data_base64 = data.template_cloudinit_config.nomad_client_config.rendered

  iam_instance_profile = var.iam_instance_profile
  key_name             = var.key_name

  security_groups             = [aws_security_group.nomad-client.id]
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

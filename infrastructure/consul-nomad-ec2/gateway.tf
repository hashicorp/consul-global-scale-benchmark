data "template_file" "consul_gateway" {
  count = var.consul_gateway_count

  template = <<EOF
${file("${path.module}/templates/consul-gateway.tpl")}
EOF
  vars = {
    consul_version                     = var.consul_version
    consul_datacenter                  = var.consul_datacenter
    retry_join_tag                     = var.retry_join_tag
    hostname                           = "consul-gateway-${var.region}-${count.index + 1}"
    envoy_version                      = var.envoy_version
    datadog_api_key                    = var.datadog_api_key
    consul_cache_use_streaming_backend = var.enable_streaming_clients
    consul_http_config_use_cache       = var.enable_streaming_clients
    consul_dns_config_use_cache        = var.enable_streaming_clients
    consul_download_url                = var.consul_download_url
    consul_tls_ca_cert_pem             = var.consul_tls_ca_cert_pem
    consul_gossip_encryption_key       = var.consul_gossip_encryption_key
  }
}

data "template_cloudinit_config" "consul_gateway_config" {
  count = var.consul_gateway_count

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
    content      = element(data.template_file.consul_gateway.*.rendered, count.index)
  }
}

resource "aws_security_group" "consul-gateway" {
  name        = "consul-gateway"
  description = "Allow everything to ingress on the Consul gateway via the internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
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

resource "aws_instance" "consul_gateway" {
  count                  = var.consul_gateway_count
  instance_type          = var.consul_gateway_instance_type
  ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.consul-gateway.id]
  iam_instance_profile   = aws_iam_instance_profile.consul-retry-join.name
  subnet_id              = element(module.vpc.public_subnets, count.index % length(module.vpc.public_subnets))
  user_data_base64       = element(data.template_cloudinit_config.consul_gateway_config.*.rendered, count.index)
  tags = {
    "Name" = "consul-gateway-${var.region}-${count.index + 1}"
  }
}
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ca_cert" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "server.${var.consul_primary_datacenter}.consul"
    organization = "HashiCorp Consul"
  }

  validity_period_hours = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing"
  ]

  is_ca_certificate = true
}

resource "tls_private_key" "server_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "server_csr" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.server_key.private_key_pem

  dns_names = [
    "consul",
    "server.${var.consul_primary_datacenter}",
    "server.${var.consul_primary_datacenter}.consul",
  ]

  subject {
    common_name  = "consul.local"
    organization = "HashiCorp Consul"
  }
}

resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem   = tls_cert_request.server_csr.cert_request_pem
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "secondary_dc_server_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "secondary_dc_server_csr" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.secondary_dc_server_key.private_key_pem

  dns_names = [
    "consul",
    "server.${var.nomad_consul_datacenter}",
    "server.${var.nomad_consul_datacenter}.consul",
  ]

  subject {
    common_name  = "server.${var.nomad_consul_datacenter}.consul"
    organization = "HashiCorp Consul"
  }
}

resource "tls_locally_signed_cert" "secondary_dc_server_cert" {
  cert_request_pem   = tls_cert_request.secondary_dc_server_csr.cert_request_pem
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

# Create consul gossip encryption key
resource "random_id" "consul_gossip_encrypt" {
  byte_length = 16
}

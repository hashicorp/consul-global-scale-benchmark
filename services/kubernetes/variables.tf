# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "service_count" {
  default = 1
}

variable "tier_1_service_instance_count" {
  default = 10
}

variable "tier_2_service_instance_count" {
  default = 15
}

variable "tier_3_service_instance_count" {
  default = 25
}

variable "tier_2_traffic_redirect" {
  default = false
}

variable "tier_1_tier_2_service_api_upstream" {
  default = false
}

variable "tier_1_tier_2_tier_3_service_hey_cross_dc_upstream" {
  default = false
}

variable "cluster_name" {
}

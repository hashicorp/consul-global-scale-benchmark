variable "service_count" {
  default = 0
}

variable "tier_1_service_instance_count" {
  default = 2
}

variable "tier_2_service_instance_count" {
  default = 3
}

variable "tier_3_service_instance_count" {
  default = 5
}

variable "tier_2_traffic_redirect" {
  default = false
}

variable "nomad_region" {
  default = "global"
}

variable "nomad_datacenter" {
  default = "dc1"
}

variable "tier_1_tier_2_tier_3_service_api_cross_dc_upstream" {
  default = false
}
# Copyright IBM Corp. 2021, 2026
# SPDX-License-Identifier: MPL-2.0

output "tier_1_service_addr_cluster_1" {
  value = module.kubernetes_cluster_services_cluster_1.tier_1_service_addr
}

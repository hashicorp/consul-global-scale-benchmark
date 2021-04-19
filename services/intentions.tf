resource "random_integer" "service_number_tier_services_deny" {
  count = var.tier_2_to_tier_3_intention_deny ? var.eks_service_count : 0

  min = 1
  max = var.eks_service_count
}

resource "consul_intention" "tier_2_to_tier_3_deny" {
  count = var.tier_2_to_tier_3_intention_deny ? var.eks_service_count : 0

  source_name      = "service-b-${count.index + 1}"
  destination_name = "service-c-${element(random_integer.service_number_tier_services_deny.*.result, count.index)}"
  action           = "deny"
}

resource "consul_intention" "tier_1_to_tier_2_deny" {
  count = var.tier_1_to_tier_2_intention_deny ? var.eks_service_count : 0

  source_name      = "service-a-${count.index + 1}"
  destination_name = "service-b-${element(random_integer.service_number_tier_services_deny.*.result, count.index)}"
  action           = "deny"
}

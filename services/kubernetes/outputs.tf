output "tier_1_service_addr" {
  # Using the function "try" to work around the empty turple error when the variable
  # service count isn't set. https://github.com/terraform-providers/terraform-provider-aws/issues/9733
  value = try(kubernetes_service.tier_1_service.0.load_balancer_ingress.0.hostname, "")
}
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  template_vars = {
    datadog_api_key = var.datadog_api_key
  }

  helm_chart_values = templatefile("${path.module}/datadog_values.yaml.tpl",
    local.template_vars
  )
}

resource "helm_release" "datadog" {
  count = lookup(var.worker_group_asg, "asg_desired_capacity", 1) >= 1 ? 1 : 0

  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = "default"

  values = [local.helm_chart_values]
}

// This service allows for sending stats from consul agents running
// on the kubernetes nodes.
// This is required as consul is installed using Helm
// and we aren't able to specify the host ip for the node
// when deploying the Helm chart for consul.
// So we create a DNS entry using the Kubernetes service 
// to connect to the datadog agents.
resource "kubernetes_service" "datadog" {
  metadata {
    name = "datadog"
  }

  spec {
    selector = {
      app = "datadog"
    }

    port {
      name        = "statsd"
      port        = 8125
      target_port = 8125
      protocol    = "UDP"
    }

    type = "ClusterIP"
  }
}

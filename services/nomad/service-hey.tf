# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "nomad_job" "service-hey" {
  count = 1

  detach = true

  jobspec = <<EOT
job "service-hey" {
  region = "${var.nomad_region}"
  datacenters = ["${var.nomad_datacenter}"]

  # Make sure this service is scheduled earlier than others in the cluster
  priority = 100

  group "service-hey" {

    count = 1

    network {
      mode = "bridge"

      port "http" {
        to     = 9090
      }
    }

    # Disable deployments to reduce scheduling overhead
    update {
      max_parallel = 0
    }

    service {
      name = "service-hey"
      port = "9090"

      connect {
        sidecar_service {}
      }

      check {
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "5s"
        timeout  = "2s"
      }

      meta {
        "consul_scalability_challenge" = "true"
      }
    }

    task "service-hey" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.17.6"

        labels {
          "com.datadoghq.ad.check_names"  = "[\"envoy\"]"
          "com.datadoghq.ad.init_configs" = "[{}]"
          "com.datadoghq.ad.instances"    = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "com.datadoghq.ad.logs"         = "[{\"source\":\"fake-service\",\"service\":\"service-hey\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      env {
        LISTEN_ADDR = "0.0.0.0:9090"
      }

      env {
        MESSAGE = "Hello this is the hey service!"
      }

      env {
        NAME = "service-hey"
      }

      env {
        TRACING_DATADOG_HOST = "$${attr.unique.network.ip-address}"
      }

      env {
        METRICS_DATADOG_HOST = "$${attr.unique.network.ip-address}"
      }

      env {
        METRICS_DATADOG_ENVIRONMENT = "nomad"
      }

      resources {
        cpu    = 500
        memory = 50 # MB
      }

    }
  }
}
EOT

  purge_on_destroy = true
}

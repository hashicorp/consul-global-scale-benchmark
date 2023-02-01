# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "nomad_job" "tier-1-service" {
  count = var.service_count

  detach = true

  jobspec = <<EOT
job "tier-1-service-a-${count.index + 1}" {
  region = "${var.nomad_region}"
  datacenters = ["${var.nomad_datacenter}"]

  priority = 1

  group "service-a" {

    count = ${var.tier_1_service_instance_count}

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
      name = "service-a-${count.index + 1}"
      port = "http"

       connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "service-b-${count.index + 1}"
              local_bind_port  = 9091
            }

            upstreams {
              destination_name = "service-hey"
              local_bind_port  = 9092
            }

            upstreams {
              destination_name = "service-api-kubernetes"
              local_bind_port  = 9093
            }

            config {
              # Note: We are using docker bridge ip address to access the datadog agent
              # on the host. Once the connect stanza supports interpolation, we can
              # use that instead. GitHub issue: https://github.com/hashicorp/nomad/issues/7221. TODO: we can now use interpolation with nomad 1.0.1.
              envoy_dogstatsd_url = "udp://172.17.0.1:8125"
            }
          }
        }
      }

      check {
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "5s"
        timeout  = "2s"
      }

      tags = ["tier-1"]
    }

    task "service-a" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.17.6"

        labels {
          "com.datadoghq.ad.check_names"  = "[\"envoy\"]"
          "com.datadoghq.ad.init_configs" = "[{}]"
          "com.datadoghq.ad.instances"    = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "com.datadoghq.ad.logs"         = "[{\"source\":\"fake-service\",\"service\":\"service-a-${count.index + 1}\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      env {
        LISTEN_ADDR = "0.0.0.0:9090"
      }

      env {
        UPSTREAM_URIS = "http://localhost:9091"
      }

      env {
        UPSTREAM_WORKERS = "1"
      }

      env {
        MESSAGE = "Welcome to the service mesh superstore running in Nomad!"
      }

      env {
        NAME = "service-a-${count.index + 1}"
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

resource "consul_config_entry" "service-api-kubernetes" {
  count = var.tier_1_tier_2_tier_3_service_api_cross_dc_upstream ? 1 : 0

  name = "service-api-kubernetes"
  kind = "service-resolver"

  config_json = jsonencode({
    redirect = {
      service    = "service-api"
      datacenter = "dc1"
    }
  })
}
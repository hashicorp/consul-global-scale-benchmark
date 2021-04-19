resource "nomad_job" "tier-3-service" {
  count = var.service_count

  detach = true

  jobspec = <<EOT
job "tier-3-service-c-${count.index + 1}" {
  region = "${var.nomad_region}"
  datacenters = ["${var.nomad_datacenter}"]

  priority = 1

  group "service-c" {

    count = ${var.tier_3_service_instance_count}

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
      name = "service-c-${count.index + 1}"
      port = "9090"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "service-hey"
              local_bind_port  = 9091
            }

            upstreams {
              destination_name = "service-api-kubernetes"
              local_bind_port  = 9092
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
    }

    task "service-c" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.17.6"

        labels {
          "com.datadoghq.ad.check_names"  = "[\"envoy\"]"
          "com.datadoghq.ad.init_configs" = "[{}]"
          "com.datadoghq.ad.instances"    = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "com.datadoghq.ad.logs"         = "[{\"source\":\"fake-service\",\"service\":\"service-c-${count.index + 1}\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      env {
        LISTEN_ADDR = "0.0.0.0:9090"
      }

      env {
        MESSAGE = "Hello, this is service-c-${count.index + 1} running on Nomad."
      }

      env {
        NAME = "service-c-${count.index + 1}"
      }

      #env {
      #  TRACING_DATADOG_HOST = "$${attr.unique.network.ip-address}"
      #}

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

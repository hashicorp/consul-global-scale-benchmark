# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "kubernetes_deployment" "tier-1-service" {
  count            = var.service_count
  wait_for_rollout = false

  metadata {
    name = "service-a-${count.index + 1}"
    labels = {
      app     = "service-a-${count.index + 1}"
      tier    = "tier-1"
      project = "consul-scalability-challenge"
    }
  }

  spec {
    replicas = var.tier_1_service_instance_count

    selector {
      match_labels = {
        app  = "service-a-${count.index + 1}"
        tier = "tier-1"
      }
    }

    template {
      metadata {
        labels = {
          app     = "service-a-${count.index + 1}"
          tier    = "tier-1"
          version = "v0.1"
          project = "consul-scalability-challenge"
        }

        annotations = {
          "consul.hashicorp.com/connect-inject"                        = "true"
          "consul.hashicorp.com/connect-service-upstreams"             = "service-b-${count.index + 1}:9091${var.tier_1_tier_2_service_api_upstream == true ? ",service-api:9092" : ""}${var.tier_1_tier_2_tier_3_service_hey_cross_dc_upstream == true ? ",service-hey:9093:dc2" : ""}"
          "consul.hashicorp.com/connect-service-name"                  = "service-a-${count.index + 1}"
          "consul.hashicorp.com/service-tags"                          = "tier-1"
          "prometheus.io/scrape"                                       = "true"
          "prometheus.io/port"                                         = "9102"
          "ad.datadoghq.com/service-a-${count.index + 1}.check_names"  = "[\"envoy\"]"
          "ad.datadoghq.com/service-a-${count.index + 1}.init_configs" = "[{}]"
          "ad.datadoghq.com/service-a-${count.index + 1}.instances"    = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "ad.datadoghq.com/consul-connect-envoy-sidecar.logs"         = "[{\"source\":\"envoy\",\"service\":\"envoy\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"cluster_manager_impl\"}]}]"
          "ad.datadoghq.com/service-a-${count.index + 1}.logs"         = "[{\"source\":\"fake-service\",\"service\":\"service-a-${count.index + 1}\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_fake_service_log_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      spec {
        container {
          image = "nicholasjackson/fake-service:v0.17.6"
          name  = "service-a-${count.index + 1}"

          port {
            name           = "http"
            container_port = 9090
          }

          env {
            name  = "LISTEN_ADDR"
            value = "0.0.0.0:9090"
          }

          env {
            name  = "UPSTREAM_URIS"
            value = "http://localhost:9091"
          }

          env {
            name  = "UPSTREAM_WORKERS"
            value = 1
          }

          env {
            name  = "MESSAGE"
            value = "Welcome to the service mesh superstore running in ${var.cluster_name} on kubernetes!"
          }

          env {
            name  = "NAME"
            value = "service-a-${count.index + 1}"
          }

          env {
            name = "TRACING_DATADOG_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "METRICS_DATADOG_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name  = "METRICS_DATADOG_ENVIRONMENT"
            value = "kubernetes"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "0.5"
              memory = "150Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 9090
            }

            initial_delay_seconds = 2
            period_seconds        = 10
          }
        }
      }
    }
  }
}



resource "kubernetes_service" "tier_1_service" {
  count = var.service_count > 0 ? 1 : 0

  metadata {
    name = "tier-1-lb"
  }

  spec {
    selector = {
      tier = "tier-1"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 9090
    }

    type = "LoadBalancer"
  }
}

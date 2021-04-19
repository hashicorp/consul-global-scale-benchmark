resource "kubernetes_deployment" "tier-3-service" {
  count            = var.service_count
  wait_for_rollout = false

  metadata {
    name = "service-c-${count.index + 1}"
    labels = {
      app     = "service-c-${count.index + 1}"
      tier    = "tier-3"
      project = "consul-scalability-challenge"
    }
  }

  spec {
    replicas = var.tier_3_service_instance_count

    selector {
      match_labels = {
        app  = "service-c-${count.index + 1}"
        tier = "tier-3"
      }
    }

    template {
      metadata {
        labels = {
          app     = "service-c-${count.index + 1}"
          tier    = "tier-3"
          version = "v0.1"
          project = "consul-scalability-challenge"
        }

        annotations = {
          "consul.hashicorp.com/connect-inject"                        = "true"
          "consul.hashicorp.com/connect-service-name"                  = "service-c-${count.index + 1}"
          "consul.hashicorp.com/connect-service-upstreams"             = "service-api:9091${var.tier_1_tier_2_tier_3_service_hey_cross_dc_upstream == true ? ",service-hey:9093:dc2" : ""}"
          "prometheus.io/scrape"                                       = "true"
          "prometheus.io/port"                                         = "9102"
          "ad.datadoghq.com/service-c-${count.index + 1}.check_names"  = "[\"envoy\"]"
          "ad.datadoghq.com/service-c-${count.index + 1}.init_configs" = "[{}]"
          "ad.datadoghq.com/service-c-${count.index + 1}.instances"    = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "ad.datadoghq.com/consul-connect-envoy-sidecar.logs"         = "[{\"source\":\"envoy\",\"service\":\"envoy\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"cluster_manager_impl\"}]}]"
          "ad.datadoghq.com/service-c-${count.index + 1}.logs"         = "[{\"source\":\"fake-service\",\"service\":\"service-c-${count.index + 1}\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_fake_service_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      spec {
        container {
          image = "nicholasjackson/fake-service:v0.17.6"
          name  = "service-c-${count.index + 1}"

          port {
            name           = "http"
            container_port = 9090
          }

          env {
            name  = "LISTEN_ADDR"
            value = "0.0.0.0:9090"
          }

          env {
            name  = "MESSAGE"
            value = "Hello, this is service-c-${count.index + 1}. I am on kubernetes running in ${var.cluster_name}."
          }

          env {
            name  = "NAME"
            value = "service-c-${count.index + 1}"
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

resource "consul_config_entry" "tier-3-resolver" {
  depends_on = [kubernetes_deployment.tier-3-service]
  count      = var.tier_2_traffic_redirect ? var.service_count : 0

  name = "service-c-${count.index + 1}"
  kind = "service-resolver"

  config_json = jsonencode({
    redirect = {
      service    = "service-c-${count.index + 1}"
      datacenter = "dc2"
    }
  })
}
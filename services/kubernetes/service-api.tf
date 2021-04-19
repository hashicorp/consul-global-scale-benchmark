resource "kubernetes_deployment" "service-api" {
  count            = var.cluster_name != "cluster-1" ? 0 : (var.tier_2_traffic_redirect ? 0 : 1)
  wait_for_rollout = false

  metadata {
    name = "service-api"
    labels = {
      app     = "service-api"
      project = "consul-scalability-challenge"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "service-api"
      }
    }

    template {
      metadata {
        labels = {
          app     = "service-api"
          version = "v0.1"
          project = "consul-scalability-challenge"
        }

        annotations = {
          "consul.hashicorp.com/connect-inject"                            = "true"
          "consul.hashicorp.com/connect-service-name"                      = "service-api"
          "consul.hashicorp.com/service-meta-consul_scalability_challenge" = "true"
          "consul.hashicorp.com/connect-sync-period"                       = "100000h"
          "prometheus.io/scrape"                                           = "true"
          "prometheus.io/port"                                             = "9102"
          "ad.datadoghq.com/service-api.check_names"                       = "[\"envoy\"]"
          "ad.datadoghq.com/service-api.init_configs"                      = "[{}]"
          "ad.datadoghq.com/service-api.instances"                         = "[{\"stats_url\": \"http://%%host%%:9105/stats\"}]"
          "ad.datadoghq.com/consul-connect-envoy-sidecar.logs"             = "[{\"source\":\"envoy\",\"service\":\"envoy\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"cluster_manager_impl\"}]}]"
          "ad.datadoghq.com/service-api.logs"                              = "[{\"source\":\"fake-service\",\"service\":\"service-api\",\"log_processing_rules\":[{\"type\":\"include_at_match\",\"name\":\"include_envoy_log_entries\",\"pattern\":\"Starting|service\"}]}]"
        }
      }

      spec {
        container {
          image = "nicholasjackson/fake-service:v0.17.6"
          name  = "service-api"

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
            value = "Hello this is the api service!"
          }

          env {
            name  = "NAME"
            value = "service-api"
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
              cpu    = "0.2"
              memory = "512Mi"
            }
            requests {
              cpu    = "0.1"
              memory = "50Mi"
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

resource "kubernetes_secret" "consul_ca_cert" {
  metadata {
    name = "consul-ca-cert"
  }

  data = {
    "ca_cert.pem" = var.consul_tls_ca_cert_pem
  }

  type = "Opaque"
}

resource "kubernetes_secret" "consul_gossip_key" {
  metadata {
    name = "consul-gossip-key"
  }

  data = {
    gossipkey = var.consul_gossip_encryption_key
  }

  type = "Opaque"
}

resource "helm_release" "consul" {
  depends_on = [kubernetes_secret.consul_ca_cert, kubernetes_secret.consul_gossip_key]

  count = lookup(var.worker_group_asg, "asg_desired_capacity", 1) >= 1 ? 1 : 0

  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  namespace  = "default"
  version    = var.consul_helm_chart_version

  ## Currently using custom built consul image with metrics
  # changes.
  set {
    name  = "global.image"
    value = "${var.consul_global_image}:${var.consul_version}"
  }

  set {
    name  = "global.imageK8S"
    value = var.consul_k8s_global_image
  }

  ## Uncomment when using custom envoy image
  #set {
  #  name  = "global.imageEnvoy"
  #  value = "${var.consul_envoy_global_image}:${var.consul_envoy_global_image_version}"
  #}

  set {
    name  = "global.datacenter"
    value = var.consul_datacenter
  }

  set {
    name  = "server.enabled"
    value = false
  }

  set {
    name  = "client.grpc"
    value = true
  }

  set {
    name  = "centralConfig.enabled"
    value = true
  }

  set {
    name  = "client.extraConfig"
    type  = "string"
    value = "\"{\\\"retry_join\\\": [\\\"provider=aws region=${var.region} tag_key=${var.retry_join_tag} tag_value=${var.retry_join_tag}\\\"]\\, \\\"primary_datacenter\\\": \\\"${var.consul_primary_datacenter}\\\"\\, \\\"telemetry\\\": {\\\"dogstatsd_addr\\\": \\\"datadog.default.svc.cluster.local:8125\\\"}\\, \\\"use_streaming_backend\\\": ${var.enable_streaming_clients}\\, \\\"http_config\\\": {\\\"use_cache\\\": ${var.enable_streaming_clients}}\\, \\\"dns_config\\\": {\\\"use_cache\\\": ${var.enable_streaming_clients}}\\, \\\"log_level\\\": \\\"${var.consul_client_log_level}\\\"\\, \\\"ca_file\\\": \\\"/consul/userconfig/consul-ca-cert/ca_cert.pem\\\"\\, \\\"verify_incoming\\\": false\\, \\\"verify_outgoing\\\": true\\, \\\"verify_server_hostname\\\": true\\, \\\"auto_encrypt\\\": {\\\"tls\\\": true}\\, \\\"disable_keyring_file\\\": true}\""
  }

  set {
    name  = "connectInject.enabled"
    value = true
  }

  set {
    name  = "connectInject.centralConfig.enabled"
    value = true
  }

  set {
    name = "connectInject.envoyExtraArgs"
    # Setting log level and concurrency to 1 to help with tracking envoy threads for logging
    value = "--log-level ${var.consul_envoy_log_level} --concurrency 1"
  }

  # Setting these above the default 50Mi as the node and service count goes up 
  # the pod tends to throw OOM errors.
  set {
    name  = "connectInject.resources.limits.memory"
    value = "500Mi"
  }

  set {
    name  = "connectInject.resources.requests.memory"
    value = "500Mi"
  }

  # Setting these above the default 50m to allow for larger node and service counts
  set {
    name  = "connectInject.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "connectInject.resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "connectInject.healthChecks.enabled"
    value = false
  }

  set {
    name  = "connectInject.priorityClassName"
    value = "system-node-critical"
  }

  set {
    name  = "global.imageK8S"
    value = "${var.consul_global_k8s_image}:latest"
  }

  set {
    name  = "meshGateway.enabled"
    value = true
  }

  set {
    name  = "meshGateway.enableHealthChecks"
    value = false
  }

  set {
    name  = "meshGateway.mode"
    value = "local"
  }

  set {
    name  = "meshGateway.wanAddress.useNodeIP"
    value = false
  }

  set {
    name  = "meshGateway.priorityClassName"
    value = "system-node-critical"
  }

  set {
    name  = "client.annotations"
    type  = "string"
    value = <<EOT
\"ad.datadoghq.com/consul.init_configs\": '[{}]'
\"ad.datadoghq.com/consul.check_names\": '[\"consul\"]'
\"ad.datadoghq.com/consul.instances\": '[{\"url\": \"http://%%host%%:8500\"}]'
EOT
  }

  # Make sure consul daemonset pod is the first one to be scheduled on the kubernetes node.
  set {
    name  = "client.priorityClassName"
    type  = "string"
    value = "system-node-critical"
  }

  # Setting this above the default 100Mi as an attempt to prevent OOM errors.
  set {
    name  = "client.resources.requests.memory"
    value = "500Mi"
  }

  set {
    name  = "client.resources.limits.memory"
    value = "500Mi"
  }

  // consul tls and gossip configuration is read from a yaml file
  // as it is more readable and easier to parse.
  values = [file("${path.module}/consul_values.yaml.tpl")]
}

datadog:
  site: datadoghq.com
  apiKey: ${datadog_api_key}
  dogstatsd:
    useHostPort: true
    nonLocalTraffic: true 
  apm:
    enabled: true
  logs:
    enabled: true
    containerCollectAll: true
  env:
   - name: "DD_CONTAINER_EXCLUDE_LOGS"
     value: "image:ghcr.io/hashicorp/consul-k8s"
   - name: "DD_CONTAINER_EXCLUDE"
     value: "image:gcr.io/datadoghq/agent"


# EKS Cluster variables
eks_consul_server_count         = 3
eks_consul_datacenter           = "dc1"
eks_consul_server_instance_type = "c5d.9xlarge"
## EKS worker group
worker_group_asg = {
  asg_desired_capacity = 3
  asg_min_size         = 3
  asg_max_size         = 3
  instance_type        = "c5.xlarge"
}
eks_enable_streaming_servers = true
eks_enable_streaming_clients = true
eks_consul_global_image      = "anubhavmishra/consul-dev"
eks_consul_k8s_global_image  = "hashicorp/consul-k8s:0.22.0"
#eks_consul_envoy_global_image         = "anubhavmishra/envoy"
#eks_consul_envoy_global_image_version = "v1.16.0"
eks_consul_client_log_level   = "INFO"
eks_consul_server_log_level   = "DEBUG"
eks_consul_enable_ui_elb      = true
eks_consul_download_url       = "https://consul-scalability-challenge.s3.amazonaws.com/consul-1.9.0-dev"
eks_consul_envoy_log_level    = "debug"
eks_consul_helm_chart_version = "0.28.0"
eks_consul_mount_ssd_volume   = true

# Nomad Cluster variables
nomad_consul_server_count         = 5
nomad_consul_datacenter           = "dc2"
nomad_consul_server_instance_type = "c5d.9xlarge"
nomad_region                      = "global"
nomad_datacenter                  = "dc1"
nomad_server_count                = 3
nomad_server_instance_type = "r5d.4xlarge"
nomad_client_instance_type = "c5.xlarge"
nomad_client_groups = [
  {
    asg_min_size         = 5000
    asg_max_size         = 5000
    asg_desired_capacity = 5000
  },
  {
    asg_min_size         = 5000
    asg_max_size         = 5000
    asg_desired_capacity = 5000
  },
]
nomad_enable_streaming_servers   = true
nomad_enable_streaming_clients   = true
consul_http_max_conns_per_client = 2000
nomad_consul_server_log_level    = "DEBUG"
nomad_consul_client_log_level    = "INFO"
nomad_consul_enable_ui_elb       = false
nomad_server_log_level           = "INFO"
nomad_client_log_level           = "INFO"
nomad_envoy_image                = "anubhavmishra/envoy:v1.16.0"
nomad_version                    = "1.0.1"
nomad_consul_download_url        = "https://consul-scalability-challenge.s3.amazonaws.com/consul-1.9.0-dev"
nomad_envoy_log_level            = "debug"
nomad_scheduler_algorithm        = "spread"
nomad_consul_mount_ssd_volume    = true
nomad_server_mount_ssd_volume    = true
# Random wait time during nomad client bootup to allow for faster scale up of all the nodes.
nomad_client_random_startup_wait_time_max = 1560 # time in seconds
nomad_consul_gateway_instance_type        = "c5a.2xlarge"

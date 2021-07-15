# EKS Cluster variables
eks_service_count                                  = 0 #600 # 2x the node count
eks_tier_1_service_instance_count                  = 2
eks_tier_2_service_instance_count                  = 16
eks_tier_3_service_instance_count                  = 20
eks_enable_loadgenerator                           = false
eks_loadgenerator_asg_min_size                     = 1
eks_loadgenerator_asg_max_size                     = 1
eks_loadgenerator_asg_desired_capacity             = 1
eks_loadgenerator_instance_type                    = "c5.large"
eks_loadgenerator_qps                              = 25
eks_loadgenerator_concurrency                      = 2
tier_2_to_tier_3_intention_deny                    = false
tier_1_tier_2_service_api_upstream                 = true
tier_1_tier_2_tier_3_service_hey_cross_dc_upstream = true
eks_loadgenerator_consul_download_url              = "" #"https://consul-scalability-challenge.s3.amazonaws.com/consul-1.9.0-dev"

# Nomad Cluster variables
nomad_service_count                                = 1000
nomad_tier_1_service_instance_count                = 10
nomad_tier_2_service_instance_count                = 83
nomad_tier_3_service_instance_count                = 85
nomad_enable_loadgenerator                         = true
nomad_loadgenerator_asg_min_size                   = 0
nomad_loadgenerator_asg_max_size                   = 0
nomad_loadgenerator_asg_desired_capacity           = 0
nomad_loadgenerator_instance_type                  = "c5.large"
nomad_loadgenerator_qps                            = 25
nomad_loadgenerator_concurrency                    = 2
tier_1_to_tier_2_intention_deny                    = false
tier_2_traffic_redirect                            = false # Redirects calls to tier 2 services on Nomad to tier 2 services in Kubernetes.
tier_1_tier_2_tier_3_service_api_cross_dc_upstream = true
nomad_loadgenerator_consul_download_url            = "" #"https://consul-scalability-challenge.s3.amazonaws.com/consul-1.9.0-dev"

# General loadgenerator settings
consul_http_max_conns_per_client = 15000
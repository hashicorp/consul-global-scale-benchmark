# Configuration can be found at: https://www.arctiq.ca/our-blog/2020/1/29/deploying-a-production-grade-consul-on-gke-using-terraform-helm-provider/
global:
  gossipEncryption:
    secretName: "consul-gossip-key"
    secretKey: "gossipkey"

client:
  extraVolumes:
    - type: secret
      name: consul-ca-cert
      load: false
    - type: secret
      name: consul-gossip-key
      load: false
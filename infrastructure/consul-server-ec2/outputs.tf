output "consul_server_ips" {
  value = length(aws_instance.consul_server) > 0 ? aws_instance.consul_server.*.public_ip : null
}

output "consul_server_ip" {
  value = length(aws_instance.consul_server) > 0 ? aws_instance.consul_server.0.public_ip : null
}

output "consul_elb" {
  value = length(aws_elb.consul_elb) > 0 ? aws_elb.consul_elb.0.dns_name : null
}

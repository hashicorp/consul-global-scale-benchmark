output "nomad_server_ips" {
  value = aws_instance.nomad_server.*.public_ip
}

output "nomad_client_asg_name" {
  value = aws_autoscaling_group.nomad_client.*.name
}

output "nomad_http_elb_address" {
  value = aws_elb.nomad_ui.dns_name
}

output "ec2_public_ips" {
  value = {
    for env, eip in aws_eip.app :
    env => eip.public_ip
  }
}

output "ec2_instance_ids" {
  value = {
    for env, instance in aws_instance.app :
    env => instance.id
  }
}

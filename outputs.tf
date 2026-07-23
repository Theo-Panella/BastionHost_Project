output "instance_ip" {
  description = "The public instances IP address"
  value       = { for k, instance in aws_instance.instances : k => instance.public_ip }
}

output "instance_private_ip" {
  description = "The private instances IP address"
  value       = { for i, instance in aws_instance.instances : i => instance.private_ip }
}
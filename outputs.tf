output "vpc_id" {
  description = "ID cua VPC"
  value       = module.vpc.vpc_id
}

output "public_ec2_ip" {
  description = "IP Public cua Bastion Host"
  value       = module.ec2.public_instance_ip
}

output "private_ec2_ip" {
  description = "IP Private cua internal EC2"
  value       = module.ec2.private_instance_ip
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_self_links" {
  description = "Self links of the private subnets"
  value       = module.vpc.private_subnet_self_links
}

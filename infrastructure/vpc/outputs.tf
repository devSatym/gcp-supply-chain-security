output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_self_link" {
  description = "The self_link of the VPC network"
  value       = google_compute_network.main.self_link
}

output "private_subnet_ids" {
  description = "Map of private subnet keys to their IDs"
  value       = { for k, s in google_compute_subnetwork.private : k => s.id }
}

output "private_subnet_self_links" {
  description = "Map of private subnet keys to their self_links (used by the GKE module)"
  value       = { for k, s in google_compute_subnetwork.private : k => s.self_link }
}

output "private_subnet_pods_range_names" {
  description = "Map of private subnet keys to their pods secondary range name"
  value       = { for k, v in var.private_subnets : k => "${k}-pods" }
}

output "private_subnet_services_range_names" {
  description = "Map of private subnet keys to their services secondary range name"
  value       = { for k, v in var.private_subnets : k => "${k}-services" }
}

output "public_subnet_ids" {
  description = "Map of public subnet keys to their IDs"
  value       = { for k, s in google_compute_subnetwork.public : k => s.id }
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "The name of the Cloud NAT gateway"
  value       = google_compute_router_nat.main.name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "get_credentials_command" {
  description = "gcloud command to fetch cluster credentials for kubectl"
  value       = module.gke.get_credentials_command
}

output "external_dns_service_account_email" {
  description = "GSA email used by External DNS"
  value       = module.kubernetes_addons.external_dns_service_account_email
}

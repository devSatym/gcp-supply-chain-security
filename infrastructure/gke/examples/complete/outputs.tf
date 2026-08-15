output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "get_credentials_command" {
  description = "gcloud command to fetch cluster credentials"
  value       = module.gke.get_credentials_command
}

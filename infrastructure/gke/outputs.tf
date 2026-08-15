output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.main.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master endpoint"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public certificate for the cluster's CA"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "The Workload Identity pool used by the cluster (project-id.svc.id.goog)"
  value       = google_container_cluster.main.workload_identity_config[0].workload_pool
}

output "node_pool_names" {
  description = "Names of all created node pools"
  value       = { for k, np in google_container_node_pool.main : k => np.name }
}

output "node_pool_service_accounts" {
  description = "Map of node pool key to its dedicated service account email"
  value       = { for k, sa in google_service_account.node_pool : k => sa.email }
}

output "get_credentials_command" {
  description = "gcloud command to fetch cluster credentials for kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --${var.regional ? "region" : "zone"} ${var.regional ? var.region : var.zone} --project ${var.project_id}"
}

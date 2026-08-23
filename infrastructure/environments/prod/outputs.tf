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

output "artifact_registry_repository" {
  description = "Docker repository URL for the supply-chain image."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.supply_chain.repository_id}"
}

output "github_workload_identity_provider" {
  description = "Full resource name for the GitHub Actions Workload Identity provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_actions_service_account_email" {
  description = "Service account GitHub Actions impersonates for GAR access."
  value       = google_service_account.github_actions.email
}

output "falco_alert_topic_id" {
  description = "Falco Pub/Sub topic ID, or null while runtime alerting is disabled."
  value       = try(module.falco_alerting[0].pubsub_topic_id, null)
}

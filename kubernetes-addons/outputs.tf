output "external_dns_service_account_email" {
  description = "Email of the Google Service Account used by External DNS"
  value       = var.enable_external_dns ? google_service_account.external_dns[0].email : null
}

output "metrics_server_release_status" {
  description = "Helm release status for metrics-server"
  value       = var.enable_metrics_server ? helm_release.metrics_server[0].status : null
}

output "external_dns_release_status" {
  description = "Helm release status for external-dns"
  value       = var.enable_external_dns ? helm_release.external_dns[0].status : null
}

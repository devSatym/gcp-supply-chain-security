output "kyverno_release_status" {
  description = "Status of the Kyverno Helm release."
  value       = helm_release.kyverno.status
}

output "kyverno_policy_name" {
  description = "Name of the rendered Azure admission policy when installation is enabled."
  value       = try(helm_release.kyverno_policy[0].name, null)
}

output "metrics_server_release_status" {
  description = "Status of the optional metrics-server release."
  value       = var.enable_metrics_server ? helm_release.metrics_server[0].status : null
}

output "argocd_release_status" {
  description = "Status of the private Argo CD Helm release when installation is enabled."
  value       = try(helm_release.argocd[0].status, null)
}

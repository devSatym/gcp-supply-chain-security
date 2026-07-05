output "namespace" {
  description = "Namespace Falco and Falcosidekick were deployed into."
  value       = kubernetes_namespace.falco.metadata[0].name
}


output "helm_release_status" {
  description = "Status of the Falco Helm release, useful for CI pipeline checks."
  value       = helm_release.falco.status
}

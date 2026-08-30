output "namespace" {
  description = "Namespace into which Falco and Falcosidekick are deployed."
  value       = kubernetes_namespace.falco.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the Falco Helm release."
  value       = helm_release.falco.status
}

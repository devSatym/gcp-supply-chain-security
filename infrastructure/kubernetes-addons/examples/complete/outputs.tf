output "external_dns_service_account_email" {
  description = "GSA email used by External DNS"
  value       = module.kubernetes_addons.external_dns_service_account_email
}

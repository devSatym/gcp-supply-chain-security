output "resource_group_name" {
  description = "Workload resource group name."
  value       = module.network.resource_group_name
}

output "private_fqdn" {
  description = "Private AKS API FQDN; resolvable only from the workload VNet or a correctly forwarded private DNS network."
  value       = module.aks.private_fqdn
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL consumed by workload-identity federated credentials."
  value       = module.aks.oidc_issuer_url
}

output "acr_id" {
  description = "Azure resource ID of the Premium ACR."
  value       = module.supply_chain.acr_id
}

output "acr_login_server" {
  description = "GitHub variable ACR_LOGIN_SERVER."
  value       = module.supply_chain.acr_login_server
}

output "application_image_repository" {
  description = "GitHub variable ACR_REPOSITORY. Append @sha256:<digest> for deployment."
  value       = module.supply_chain.application_image_repository
}

output "cosign_metadata_repository" {
  description = "GitHub variable COSIGN_REPOSITORY (mutable Cosign metadata)."
  value       = module.supply_chain.cosign_metadata_repository
}

output "github_ci_client_id" {
  description = "GitHub variable AZURE_CLIENT_ID for azure/login."
  value       = module.supply_chain.github_ci_client_id
}

output "github_ci_aks_cluster_user_role_assignment_id" {
  description = "Role-assignment ID granting the GitHub CI identity AKS Cluster User access (non-admin kubeconfig retrieval only)."
  value       = azurerm_role_assignment.github_ci_aks_cluster_user.id
}

output "github_ci_aks_default_namespace_writer_role_assignment_id" {
  description = "Role-assignment ID granting the GitHub CI identity AKS RBAC Writer access scoped to the default namespace only."
  value       = azurerm_role_assignment.github_ci_aks_default_namespace_writer.id
}

output "kyverno_client_id" {
  description = "Client ID annotated on Kyverno's admission-controller ServiceAccount."
  value       = module.supply_chain.kyverno_client_id
}

output "tenant_id" {
  description = "GitHub variable AZURE_TENANT_ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "GitHub variable AZURE_SUBSCRIPTION_ID."
  value       = data.azurerm_client_config.current.subscription_id
}

output "nat_public_ip_address" {
  description = "Controlled NAT egress IP for ACR/state firewall allowlists."
  value       = module.network.nat_public_ip_address
}

output "flow_log_id" {
  description = "Azure VNet flow-log resource ID when enabled; otherwise null."
  value       = module.network.flow_log_id
}

output "flow_logs_storage_account_id" {
  description = "Dedicated VNet flow-log storage account ID when flow logs are enabled; otherwise null."
  value       = module.network.flow_logs_storage_account_id
}

output "registry_public_access_enabled" {
  description = "Whether authenticated public network access remains enabled for ACR."
  value       = !var.disable_public_network_access
}

output "private_endpoint_subnet_id" {
  description = "Non-secret subnet ID reserved for Azure Private Endpoints."
  value       = module.network.private_endpoints_subnet_id
}

output "functions_subnet_id" {
  description = "Non-secret delegated subnet ID used by the optional Function VNet integration."
  value       = module.network.functions_subnet_id
}

output "private_dns_zone_ids" {
  description = "Non-secret Private Link DNS zone IDs used by the endpoint probes."
  value       = module.network.private_dns_zone_ids
}

output "private_endpoint_creation_enabled" {
  description = "Whether this state includes the Private Endpoint resources."
  value       = var.enable_private_endpoints
}

output "public_network_access_closure_enabled" {
  description = "Whether public service access has been closed after endpoint probing."
  value       = var.disable_public_network_access
}

output "acr_name" {
  description = "ACR name used by private endpoint and release preflight checks."
  value       = module.supply_chain.acr_name
}

output "eventhub_namespace_fqdn" {
  description = "Event Hubs namespace FQDN when runtime alerting is enabled; otherwise null."
  value       = try(module.falco_alerting[0].eventhub_namespace_fqdn, null)
}

output "key_vault_uri" {
  description = "Key Vault URI for private DNS/connectivity checks when alerting is enabled."
  value       = try(module.falco_alerting[0].key_vault_uri, null)
}

output "function_storage_blob_endpoint" {
  description = "Function host storage Blob endpoint for private connectivity checks."
  value       = try(module.falco_alerting[0].function_storage_blob_endpoint, null)
}

output "function_storage_queue_endpoint" {
  description = "Function host storage Queue endpoint for private connectivity checks."
  value       = try(module.falco_alerting[0].function_storage_queue_endpoint, null)
}

output "function_storage_table_endpoint" {
  description = "Function host storage Table endpoint for private connectivity checks."
  value       = try(module.falco_alerting[0].function_storage_table_endpoint, null)
}

output "falco_function_name" {
  description = "Discord notifier Function name when runtime alerting is enabled; otherwise null."
  value       = try(module.falco_alerting[0].function_name, null)
}

data "azurerm_client_config" "current" {}

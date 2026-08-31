output "acr_id" {
  description = "Azure resource ID of the Premium ACR."
  value       = azurerm_container_registry.this.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "acr_login_server" {
  description = "ACR login server for Azure CI and digest-pinned Kubernetes image references."
  value       = azurerm_container_registry.this.login_server
}

output "application_repository" {
  description = "Application repository path inside ACR. It is intentionally separate from Cosign metadata."
  value       = var.application_repository
}

output "application_image_repository" {
  description = "Fully qualified ACR application image repository; append @sha256:<digest> for deployment."
  value       = "${azurerm_container_registry.this.login_server}/${var.application_repository}"
}

output "cosign_metadata_repository" {
  description = "Fully qualified mutable COSIGN_REPOSITORY path for legacy Cosign signature and attestation indexes."
  value       = "${azurerm_container_registry.this.login_server}/${var.cosign_metadata_repository}"
}

output "cosign_repository" {
  description = "Compatibility output for COSIGN_REPOSITORY; points to the separate mutable Cosign metadata repository."
  value       = "${azurerm_container_registry.this.login_server}/${var.cosign_metadata_repository}"
}

output "github_ci_client_id" {
  description = "Client ID for azure/login in the trusted main-branch GitHub Actions workflow."
  value       = azurerm_user_assigned_identity.github_ci.client_id
}

output "github_actions_client_id" {
  description = "Compatibility output for the GitHub Actions UAMI client ID used by azure/login."
  value       = azurerm_user_assigned_identity.github_ci.client_id
}

output "github_ci_principal_id" {
  description = "Object ID of the GitHub CI managed identity."
  value       = azurerm_user_assigned_identity.github_ci.principal_id
}

output "github_ci_federated_identity_credential_id" {
  description = "Resource ID of the immutable GitHub trusted-main federated identity credential."
  value       = azurerm_federated_identity_credential.github_ci_main_immutable.id
}

output "github_ci_oidc_subject" {
  description = "Exact GitHub OIDC subject trusted by the CI managed identity."
  value       = local.github_ci_subject
}

output "github_terraform_client_id" {
  description = "GitHub variable AZURE_TERRAFORM_CLIENT_ID for main-only remote Terraform convergence."
  value       = try(azurerm_user_assigned_identity.github_terraform[0].client_id, null)
}

output "github_terraform_principal_id" {
  description = "Object ID of the separate GitHub Terraform managed identity when enabled."
  value       = try(azurerm_user_assigned_identity.github_terraform[0].principal_id, null)
}

output "kyverno_client_id" {
  description = "Client ID to place in Kyverno's azure.workload.identity/client-id ServiceAccount annotation."
  value       = azurerm_user_assigned_identity.kyverno.client_id
}

output "kyverno_principal_id" {
  description = "Object ID of Kyverno's ACR reader managed identity."
  value       = azurerm_user_assigned_identity.kyverno.principal_id
}

output "kyverno_federated_identity_credential_id" {
  description = "Resource ID of the AKS ServiceAccount-to-Kyverno managed-identity federated credential."
  value       = azurerm_federated_identity_credential.kyverno.id
}

output "kyverno_service_account_subject" {
  description = "Exact AKS ServiceAccount subject trusted by the Kyverno managed identity."
  value       = local.kyverno_service_subject
}

output "github_ci_repository_writer_role_assignment_id" {
  description = "Role assignment granting GitHub CI repository-scoped writer access (combined application + metadata condition)."
  value       = azurerm_role_assignment.github_ci_repository_writer.id
}

output "kyverno_repository_reader_role_assignment_id" {
  description = "Role assignment granting Kyverno repository-scoped reader access (combined application + metadata condition)."
  value       = azurerm_role_assignment.kyverno_repository_reader.id
}

output "aks_kubelet_repository_reader_role_assignment_id" {
  description = "Role assignment granting the AKS kubelet identity repository-scoped reader access (combined application + metadata condition)."
  value       = azurerm_role_assignment.aks_kubelet_repository_reader.id
}

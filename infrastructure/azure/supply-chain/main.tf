locals {
  # This identity is deliberately fixed to the protected release ref. The
  # feature branch can validate this module, but it cannot exchange a GitHub
  # OIDC token for Azure production access.
  github_oidc_issuer      = "https://token.actions.githubusercontent.com"
  github_oidc_audience    = "api://AzureADTokenExchange"
  github_release_ref      = "refs/heads/main"
  github_ci_subject       = "repo:${var.github_repository}:ref:${local.github_release_ref}"
  kyverno_service_subject = "system:serviceaccount:${var.kyverno_namespace}:${var.kyverno_service_account_name}"
  protected_repositories  = toset([var.application_repository, var.cosign_metadata_repository])

  tags = merge(var.tags, {
    managed_by = "terraform"
    component  = "supply-chain"
  })

  # Azure deduplicates role assignments by (principal, role, scope): separate
  # per-repository assignments collide with RoleAssignmentExists. Both
  # repository paths are therefore combined into a single assignment per
  # role with an OR of StringEqualsIgnoreCase conditions.
  repository_writer_condition = <<-EOT
    (
      (
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/read'})
        AND
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/write'})
        AND
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/read'})
        AND
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/write'})
      )
      OR
      (
        @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase '${var.application_repository}'
      )
      OR
      (
        @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase '${var.cosign_metadata_repository}'
      )
    )
  EOT

  repository_reader_condition = <<-EOT
    (
      (
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/read'})
        AND
        !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/read'})
      )
      OR
      (
        @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase '${var.application_repository}'
      )
      OR
      (
        @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase '${var.cosign_metadata_repository}'
      )
    )
  EOT
}

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"

  # Never use the registry admin user or anonymous pulls. Public network
  # access remains an explicit, authenticated bootstrap choice until the
  # network module supplies private endpoints and a private CI execution path.
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = var.public_network_access_enabled
  network_rule_bypass_option    = "None"
  data_endpoint_enabled         = true
  retention_policy_in_days      = var.untagged_manifest_retention_days
  role_assignment_mode          = "AbacRepositoryPermissions"

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.application_repository != var.cosign_metadata_repository
      error_message = "application_repository and cosign_metadata_repository must remain separate so application locking never blocks legacy Cosign metadata updates."
    }

    precondition {
      condition     = !var.enable_aks_kubelet_catalog_lister || var.aks_kubelet_principal_id != null
      error_message = "enable_aks_kubelet_catalog_lister requires aks_kubelet_principal_id."
    }
  }
}

# GitHub Actions receives a dedicated managed identity. Its only registry
# permissions are repository writer grants on the two known paths below.
resource "azurerm_user_assigned_identity" "github_ci" {
  name                = "${var.name_prefix}-github-ci"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_ci_main" {
  name                = "github-main"
  resource_group_name = var.resource_group_name
  audience            = [local.github_oidc_audience]
  issuer              = local.github_oidc_issuer
  parent_id           = azurerm_user_assigned_identity.github_ci.id
  subject             = local.github_ci_subject
}

resource "azurerm_role_assignment" "github_ci_repository_writer" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Writer"
  principal_id                     = azurerm_user_assigned_identity.github_ci.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  condition                        = local.repository_writer_condition
  condition_version                = "2.0"
  description                      = "GitHub CI writer access limited to ${var.application_repository} and ${var.cosign_metadata_repository}."
}

resource "azurerm_role_assignment" "github_ci_catalog_lister" {
  count = var.enable_github_ci_catalog_lister ? 1 : 0

  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Catalog Lister"
  principal_id                     = azurerm_user_assigned_identity.github_ci.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Optional registry-wide catalog listing for GitHub CI."
}

# Kyverno's admission controller is the only Kubernetes ServiceAccount trusted
# to exchange an AKS OIDC token for this identity. It can read the application
# and Cosign metadata repositories, but cannot write or enumerate all repos.
resource "azurerm_user_assigned_identity" "kyverno" {
  name                = "${var.name_prefix}-kyverno-verifier"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "kyverno" {
  name                = "kyverno-admission-controller"
  resource_group_name = var.resource_group_name
  audience            = [local.github_oidc_audience]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.kyverno.id
  subject             = local.kyverno_service_subject
}

resource "azurerm_role_assignment" "kyverno_repository_reader" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Reader"
  principal_id                     = azurerm_user_assigned_identity.kyverno.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  condition                        = local.repository_reader_condition
  condition_version                = "2.0"
  description                      = "Kyverno admission verification reader access limited to ${var.application_repository} and ${var.cosign_metadata_repository}."
}

resource "azurerm_role_assignment" "kyverno_catalog_lister" {
  count = var.enable_kyverno_catalog_lister ? 1 : 0

  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Catalog Lister"
  principal_id                     = azurerm_user_assigned_identity.kyverno.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Optional registry-wide catalog listing for Kyverno."
}

# AKS creates the kubelet managed identity in the AKS module. Accepting its
# principal ID here avoids creating a second pull identity while retaining the
# same repository-scoped access used by Kyverno.
resource "azurerm_role_assignment" "aks_kubelet_repository_reader" {
  # Unknown-at-plan principal values are fine in resource arguments; the
  # precondition still fails closed when the caller supplies no principal.
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Reader"
  principal_id                     = var.aks_kubelet_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  condition                        = local.repository_reader_condition
  condition_version                = "2.0"
  description                      = "AKS kubelet reader access limited to ${var.application_repository} and ${var.cosign_metadata_repository}."

  lifecycle {
    precondition {
      condition     = var.aks_kubelet_principal_id != null
      error_message = "aks_kubelet_repository_reader requires aks_kubelet_principal_id; pass the AKS module's kubelet_identity_object_id."
    }
  }
}

resource "azurerm_role_assignment" "aks_kubelet_catalog_lister" {
  count = var.enable_aks_kubelet_catalog_lister ? 1 : 0

  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "Container Registry Repository Catalog Lister"
  principal_id                     = var.aks_kubelet_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Optional registry-wide catalog listing for the AKS kubelet identity."

  lifecycle {
    precondition {
      condition     = var.aks_kubelet_principal_id != null
      error_message = "enable_aks_kubelet_catalog_lister requires aks_kubelet_principal_id."
    }
  }
}

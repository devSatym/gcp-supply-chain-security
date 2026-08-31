locals {
  # This identity is deliberately fixed to the protected release ref. The
  # feature branch can validate this module, but it cannot exchange a GitHub
  # OIDC token for Azure production access.
  github_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_oidc_audience = "api://AzureADTokenExchange"
  github_release_ref   = "refs/heads/main"
  # GitHub's immutable OIDC subject uses the repository owner and repository
  # numeric IDs. It remains stable across repository renames and is materially
  # safer than a mutable name-only subject. The exact subject is supplied by
  # the environment after verifying GitHub's OIDC customization response.
  github_ci_subject       = var.github_oidc_subject
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
  # Retain the legacy name-based credential during the one-time OIDC
  # migration. It has no usable subject once immutable OIDC is enabled, and
  # is removed only after the immutable path has been proven in CI.
  subject = "repo:${var.github_repository}:ref:${local.github_release_ref}"
}

resource "azurerm_federated_identity_credential" "github_ci_main_immutable" {
  name                = "github-main-immutable"
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

# Terraform receives a distinct identity from release CI. It exists only when
# the environment supplies the exact remote-state account and workload scopes;
# no static client credentials, storage keys, or kubeconfig are ever needed.
resource "azurerm_user_assigned_identity" "github_terraform" {
  count = var.enable_github_terraform_identity ? 1 : 0

  name                = "${var.name_prefix}-github-terraform"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  lifecycle {
    precondition {
      condition = (
        var.terraform_workload_scope_id != null &&
        var.terraform_aks_scope_id != null &&
        var.terraform_state_storage_account_id != null
      )
      error_message = "The Terraform identity requires workload, AKS, and remote-state resource IDs."
    }
  }
}

resource "azurerm_federated_identity_credential" "github_terraform_main_immutable" {
  count = var.enable_github_terraform_identity ? 1 : 0

  name                = "github-terraform-main-immutable"
  resource_group_name = var.resource_group_name
  audience            = [local.github_oidc_audience]
  issuer              = local.github_oidc_issuer
  parent_id           = azurerm_user_assigned_identity.github_terraform[0].id
  subject             = var.github_oidc_subject
}

resource "azurerm_role_assignment" "github_terraform_workload_contributor" {
  count = var.enable_github_terraform_identity ? 1 : 0

  scope                            = var.terraform_workload_scope_id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.github_terraform[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Terraform convergence identity for the Azure workload resource group."
}

resource "azurerm_role_assignment" "github_terraform_workload_access_admin" {
  count = var.enable_github_terraform_identity ? 1 : 0

  scope                            = var.terraform_workload_scope_id
  role_definition_name             = "User Access Administrator"
  principal_id                     = azurerm_user_assigned_identity.github_terraform[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Terraform convergence identity may create only workload-scoped role assignments."
}

resource "azurerm_role_assignment" "github_terraform_aks_cluster_admin" {
  count = var.enable_github_terraform_identity ? 1 : 0

  scope                            = var.terraform_aks_scope_id
  role_definition_name             = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id                     = azurerm_user_assigned_identity.github_terraform[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Terraform convergence identity administers only this private AKS cluster."
}

resource "azurerm_role_assignment" "github_terraform_state_blob_contributor" {
  count = var.enable_github_terraform_identity ? 1 : 0

  scope                            = var.terraform_state_storage_account_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.github_terraform[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Terraform convergence identity may read and lock only remote Azure Blob state."
}

# The AzureRM provider refreshes role assignments before deciding whether an
# update is required. This management-plane Reader grant is limited to the
# state storage account; it does not grant data-plane Blob access by itself.
resource "azurerm_role_assignment" "github_terraform_state_reader" {
  count = var.enable_github_terraform_identity ? 1 : 0

  # Pin the assignment UUID when adopting an existing remote-state bootstrap
  # grant. Azure role-assignment names are immutable, so leaving this unset
  # would make Terraform replace an otherwise identical least-privilege grant.
  name                             = var.terraform_state_reader_assignment_name
  scope                            = var.terraform_state_storage_account_id
  role_definition_name             = "Reader"
  principal_id                     = azurerm_user_assigned_identity.github_terraform[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
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

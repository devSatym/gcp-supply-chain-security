variable "resource_group_name" {
  description = "Name of the existing Azure resource group that owns the registry and managed identities."
  type        = string
}

variable "location" {
  description = "Azure region for the registry and user-assigned managed identities."
  type        = string
}

variable "name_prefix" {
  description = "Short, globally meaningful prefix used in managed-identity names."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,64}$", var.name_prefix))
    error_message = "name_prefix must contain only letters, numbers, and hyphens and be at most 64 characters."
  }
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name. Azure permits only alphanumeric characters, 5-50 characters."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 alphanumeric characters with no hyphens or underscores."
  }
}

variable "application_repository" {
  description = "ACR repository for release images. The repository is created by the first image push, not by Terraform."
  type        = string
  default     = "supply-chain-security/supply-chain-demo"

  validation {
    condition     = can(regex("^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*$", var.application_repository))
    error_message = "application_repository must be a lower-case ACR repository path."
  }
}

variable "cosign_metadata_repository" {
  description = "Separate mutable ACR repository used through COSIGN_REPOSITORY for legacy Cosign signature and attestation indexes."
  type        = string
  default     = "supply-chain-security-attestations/supply-chain-demo"

  validation {
    condition     = can(regex("^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*$", var.cosign_metadata_repository))
    error_message = "cosign_metadata_repository must be a lower-case ACR repository path."
  }
}

variable "github_repository" {
  description = "Canonical GitHub repository allowed to exchange an OIDC token for the CI managed identity."
  type        = string
  default     = "devSatym/gcp-supply-chain-security"

  validation {
    condition     = var.github_repository == "devSatym/gcp-supply-chain-security"
    error_message = "Only devSatym/gcp-supply-chain-security is trusted by this Azure implementation."
  }
}

variable "github_oidc_subject" {
  description = "Exact immutable GitHub Actions OIDC subject for trusted main. Obtain this from the repository OIDC customization response; never substitute a branch, PR, or environment subject."
  type        = string
  default     = "repo:devSatym@192846686/gcp-supply-chain-security@1343453581:ref:refs/heads/main"

  validation {
    condition     = var.github_oidc_subject == "repo:devSatym@192846686/gcp-supply-chain-security@1343453581:ref:refs/heads/main"
    error_message = "github_oidc_subject must remain the immutable trusted-main subject for devSatym/gcp-supply-chain-security."
  }
}

variable "enable_github_terraform_identity" {
  description = "Create the separate main-only GitHub OIDC identity used for remote Terraform convergence."
  type        = bool
  default     = false
}

variable "terraform_workload_scope_id" {
  description = "Resource ID of the workload resource group where the Terraform identity receives Contributor and User Access Administrator. Required only when enable_github_terraform_identity is true."
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_aks_scope_id" {
  description = "Resource ID of the private AKS cluster where the Terraform identity receives cluster-admin. Required only when enable_github_terraform_identity is true."
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_state_storage_account_id" {
  description = "Resource ID of the Azure Blob remote-state storage account where the Terraform identity receives data-plane state access. Required only when enable_github_terraform_identity is true."
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_state_reader_assignment_name" {
  description = "Optional existing Azure role-assignment UUID for the remote-state Reader grant. Set when Terraform adopts a bootstrap assignment so convergence never replaces it."
  type        = string
  default     = null
  nullable    = true
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL emitted by the private AKS cluster. It is used only for Kubernetes workload identity credentials."
  type        = string

  validation {
    condition     = can(regex("^https://", var.aks_oidc_issuer_url))
    error_message = "aks_oidc_issuer_url must be an HTTPS URL from the AKS OIDC issuer output."
  }
}

variable "kyverno_namespace" {
  description = "Namespace containing Kyverno's admission-controller ServiceAccount."
  type        = string
  default     = "kyverno"
}

variable "kyverno_service_account_name" {
  description = "Kyverno admission-controller Kubernetes ServiceAccount name trusted by its managed identity."
  type        = string
  default     = "kyverno-admission-controller"
}

variable "aks_kubelet_principal_id" {
  description = "Optional AKS kubelet managed-identity principal ID. When set, it receives ACR repository-reader access for both required repositories."
  type        = string
  default     = null
  nullable    = true
}

variable "public_network_access_enabled" {
  description = "Whether authenticated public network access to ACR is enabled. Set false only after the network module creates private endpoints, DNS, and a private-capable CI runner."
  type        = bool
  default     = true
}

variable "untagged_manifest_retention_days" {
  description = "Days to retain untagged manifests in Premium ACR before purge."
  type        = number
  default     = 30

  validation {
    condition     = var.untagged_manifest_retention_days >= 1 && var.untagged_manifest_retention_days <= 365
    error_message = "untagged_manifest_retention_days must be between 1 and 365."
  }
}

variable "enable_github_ci_catalog_lister" {
  description = "Grant GitHub CI the registry-wide catalog-lister role. Disabled by default because known repository paths do not require repository enumeration."
  type        = bool
  default     = false
}

variable "enable_kyverno_catalog_lister" {
  description = "Grant Kyverno the registry-wide catalog-lister role. Disabled by default because admission verification uses known repository paths."
  type        = bool
  default     = false
}

variable "enable_aks_kubelet_catalog_lister" {
  description = "Grant the optional AKS kubelet identity the registry-wide catalog-lister role. Disabled by default; requires aks_kubelet_principal_id."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional Azure resource tags. Required ownership and cost tags should be supplied by the environment root."
  type        = map(string)
  default     = {}
}

variable "kyverno_client_id" {
  description = "Client ID of the dedicated Kyverno ACR-reader UAMI."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.kyverno_client_id))
    error_message = "kyverno_client_id must be a managed identity client UUID."
  }
}

variable "acr_login_server" {
  description = "ACR login server used by the Azure Kyverno policy template."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+\\.azurecr\\.io$", var.acr_login_server))
    error_message = "acr_login_server must be an Azure Container Registry login server."
  }
}

variable "application_repository" {
  description = "Application repository path inside ACR, without the login-server hostname."
  type        = string
}

variable "cosign_repository" {
  description = "Fully qualified mutable COSIGN_REPOSITORY path."
  type        = string
}

variable "kyverno_chart_version" {
  description = "Pinned Kyverno Helm chart version."
  type        = string
  default     = "3.9.0"
}

variable "kyverno_namespace" {
  description = "Namespace used for the Kyverno Helm release."
  type        = string
  default     = "kyverno"
}

variable "kyverno_values_template_path" {
  description = "Path to the Azure Kyverno values template."
  type        = string
  default     = null
}

variable "kyverno_policy_template_path" {
  description = "Path to the Azure ClusterPolicy template."
  type        = string
  default     = null
}

variable "argocd_chart_version" {
  description = "Pinned argo-cd Helm chart version for the in-cluster private GitOps controller."
  type        = string
  default     = "10.3.3"
}

variable "install_argocd" {
  description = "Install the private Argo CD foundation alongside the workload add-ons."
  type        = bool
  default     = true
}

variable "install_policy" {
  description = "Apply the rendered ClusterPolicy after the Kyverno chart creates its CRDs."
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install an extra metrics-server only when AKS's managed metrics path is deliberately not used."
  type        = bool
  default     = false
}

variable "metrics_server_chart_version" {
  description = "Pinned metrics-server Helm chart version for the optional add-on."
  type        = string
  default     = "3.12.2"
}

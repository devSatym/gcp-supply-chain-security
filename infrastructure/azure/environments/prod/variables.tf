variable "resource_group_name" {
  description = "Name of the workload resource group created by the network module."
  type        = string
}

variable "environment" {
  description = "Deployment environment used for governance tags (dev/staging/prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for the whole estate. Placeholder until the owner supplies the real region."
  type        = string
}

variable "vnet_name" {
  description = "Name of the workload VNet."
  type        = string
  default     = "vnet-supply-chain-prod"
}

variable "vnet_address_space" {
  description = "CIDR ranges for the workload VNet. Must not overlap the AKS pod/service CIDRs."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_nodes_subnet_name" {
  description = "Name of the non-delegated AKS node-pool subnet."
  type        = string
  default     = "snet-aks-nodes"
}

variable "aks_nodes_subnet_address_prefixes" {
  description = "Address prefixes for the AKS node subnet."
  type        = list(string)
  default     = ["10.0.0.0/20"]
}

variable "aks_api_server_subnet_address_prefixes" {
  description = "Address prefixes for the delegated AKS API-server subnet (minimum /28)."
  type        = list(string)
  default     = ["10.0.16.0/28"]
}

variable "private_endpoints_subnet_address_prefixes" {
  description = "Address prefixes for the Private Endpoints subnet."
  type        = list(string)
  default     = ["10.0.32.0/24"]
}

variable "functions_subnet_address_prefixes" {
  description = "Address prefixes for the Azure Functions VNet-integration subnet."
  type        = list(string)
  default     = ["10.0.48.0/24"]
}

variable "owner_ssh_allow_cidr" {
  description = "Operator CIDR permitted to SSH to AKS nodes for the private-network jump host."
  type        = string
  default     = null
}

variable "enable_flow_logs" {
  description = "Enable Azure VNet flow logs. Keep false until the owner supplies a dedicated flow-log storage account name and confirms subscription support."
  type        = bool
  default     = false
}

variable "flow_logs_storage_account_name" {
  description = "Owner-supplied globally unique lowercase StorageV2 account name for VNet flow logs; required only when enable_flow_logs is true."
  type        = string
  default     = null
}

variable "flow_logs_storage_account_replication_type" {
  description = "Replication SKU for the dedicated VNet flow-log storage account."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.flow_logs_storage_account_replication_type)
    error_message = "flow_logs_storage_account_replication_type must be a supported standard StorageV2 replication SKU."
  }
}

variable "flow_logs_retention_days" {
  description = "Retention period for Azure VNet flow logs."
  type        = number
  default     = 30

  validation {
    condition     = var.flow_logs_retention_days >= 1 && var.flow_logs_retention_days <= 365
    error_message = "flow_logs_retention_days must be between 1 and 365."
  }
}

variable "aks_sku_tier" {
  description = "AKS pricing tier (Free/Standard/Premium)."
  type        = string
  default     = "Standard"
}

variable "node_os_upgrade_channel" {
  description = "AKS node OS upgrade channel. NodeImage matches the managed GCP node-image maintenance behavior."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["Unmanaged", "SecurityPatch", "NodeImage", "None"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be Unmanaged, SecurityPatch, NodeImage, or None."
  }
}

variable "enable_maintenance_windows" {
  description = "Whether Terraform should manage the AKS maintenance windows. Keep enabled for the normal deployment; disable only for a staged apply while the AKS write role propagates."
  type        = bool
  default     = true
}

variable "maintenance_window_frequency" {
  description = "AKS maintenance-window frequency. The Azure parity contract uses a daily window."
  type        = string
  default     = "Daily"

  validation {
    condition     = var.maintenance_window_frequency == "Daily"
    error_message = "maintenance_window_frequency must remain Daily for the GCP parity contract."
  }
}

variable "maintenance_window_interval" {
  description = "Interval for the AKS maintenance window."
  type        = number
  default     = 1

  validation {
    condition     = var.maintenance_window_interval >= 1
    error_message = "maintenance_window_interval must be at least 1."
  }
}

variable "maintenance_window_duration_hours" {
  description = "Duration of the AKS maintenance window in hours."
  type        = number
  default     = 4

  validation {
    condition     = var.maintenance_window_duration_hours >= 4 && var.maintenance_window_duration_hours <= 24
    error_message = "maintenance_window_duration_hours must be between 4 and 24."
  }
}

variable "maintenance_window_start_time" {
  description = "Daily AKS maintenance-window start time in HH:MM."
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window_start_time))
    error_message = "maintenance_window_start_time must be HH:MM in 24-hour time."
  }
}

variable "maintenance_window_utc_offset" {
  description = "UTC offset for the AKS maintenance window."
  type        = string
  default     = "+00:00"

  validation {
    condition     = can(regex("^[+-]([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window_utc_offset))
    error_message = "maintenance_window_utc_offset must use a signed HH:MM offset."
  }
}

variable "pod_cidr" {
  description = "Non-overlapping Azure CNI Overlay pod CIDR."
  type        = string
  default     = "10.4.0.0/14"
}

variable "service_cidr" {
  description = "Non-overlapping Kubernetes service CIDR."
  type        = string
  default     = "10.8.0.0/20"
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP inside the service CIDR."
  type        = string
  default     = "10.8.0.10"
}

variable "cluster_name" {
  description = "Name of the private AKS cluster."
  type        = string
  default     = "aks-supply-chain-prod"
}

variable "azure_rbac_admin_group_object_ids" {
  description = "Entra group object IDs granted AKS cluster-admin through Azure RBAC. Use groups, never individuals."
  type        = set(string)
}

variable "system_node_pool" {
  description = "System node-pool configuration for the private AKS cluster."
  type = object({
    name         = string
    vm_size      = string
    min_size     = number
    max_size     = number
    desired_size = number
    max_pods     = optional(number, 30)
  })
  default = {
    name         = "system"
    vm_size      = "Standard_D4s_v5"
    min_size     = 2
    max_size     = 5
    desired_size = 2
  }
}

variable "user_node_pools" {
  description = "Optional managed user node pools."
  type = map(object({
    name         = string
    vm_size      = string
    min_size     = number
    max_size     = number
    desired_size = number
  }))
  default = {}
}

variable "name_prefix" {
  description = "Short prefix for managed identities and private endpoints (letters, numbers, hyphens)."
  type        = string
  default     = "supplychain-prod"
}

variable "acr_name" {
  description = "Owner-approved, globally unique ACR name (5-50 alphanumeric characters). Supply it outside source control; there is deliberately no default."
  type        = string
}

variable "application_repository" {
  description = "ACR repository path for release images."
  type        = string
  default     = "supply-chain-security/supply-chain-demo"
}

variable "cosign_metadata_repository" {
  description = "Separate mutable ACR repository path for Cosign signature and attestation indexes."
  type        = string
  default     = "supply-chain-security-attestations/supply-chain-demo"
}

variable "kyverno_chart_version" {
  description = "Pinned Kyverno Helm chart version used by the add-ons module."
  type        = string
  default     = "3.9.0"
}

variable "argocd_chart_version" {
  description = "Pinned argo-cd Helm chart version used by the private GitOps foundation."
  type        = string
  default     = "10.3.3"
}

variable "install_argocd" {
  description = "Install the private, in-cluster Argo CD foundation during the workload add-ons stage."
  type        = bool
  default     = true
}

variable "install_kyverno_policy" {
  description = "Apply the rendered Azure ClusterPolicy during the add-ons stage."
  type        = bool
  default     = true
}

variable "enable_workload_addons" {
  description = "Stage-2 gate: install Kyverno and Falco once the private API server is reachable from the applying host."
  type        = bool
  default     = false
}

variable "enable_runtime_alerting" {
  description = "Opt-in gate for the Discord alerting plane (Event Hubs, Key Vault, Function). Discord is disabled unless this is true."
  type        = bool
  default     = false
}

variable "enable_private_endpoints" {
  description = "Create Private Endpoints for ACR/Key Vault/Event Hubs/Function storage. This does not disable public service access; use disable_public_network_access after private DNS and connectivity are proven."
  type        = bool
  default     = false
}

variable "disable_public_network_access" {
  description = "Final private-closure gate for ACR, Key Vault, Event Hubs, and Function storage. It requires enable_private_endpoints and is applied only after private DNS/connectivity probes succeed. AKS remains private regardless of this flag."
  type        = bool
  default     = false
}

variable "falco_minimum_priority" {
  description = "Lowest Falco priority forwarded to Event Hubs and Discord."
  type        = string
  default     = "notice"
}

variable "alerting_name_prefix" {
  description = "Owner-approved lowercase 3-15 character prefix for the alerting plane's globally unique Event Hubs, Key Vault, and Storage names. Supply it outside source control; there is deliberately no default."
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord incoming webhook URL. Supply only through TF_VAR_discord_webhook_url; it lands in a write-only Key Vault field. Ignored while enable_runtime_alerting is false."
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_webhook_secret_version" {
  description = "Non-secret write-only Key Vault secret version counter used when the opt-in Discord webhook rotates."
  type        = number
  default     = 1

  validation {
    condition     = var.discord_webhook_secret_version >= 1 && floor(var.discord_webhook_secret_version) == var.discord_webhook_secret_version
    error_message = "discord_webhook_secret_version must be a positive integer."
  }
}

variable "discord_webhook_secret_expiration_date" {
  description = "Owner-supplied UTC expiration for the write-only Discord webhook secret. Required whenever runtime alerting is enabled."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.discord_webhook_secret_expiration_date == null || can(formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", var.discord_webhook_secret_expiration_date))
    error_message = "discord_webhook_secret_expiration_date must be a UTC timestamp such as 2030-01-01T00:00:00Z."
  }
}

variable "alerting_trusted_public_ip_ranges" {
  description = "Owner-supplied Terraform-runner CIDRs that may write the Discord webhook while alerting services retain public access. Leave empty only for private-endpoint deployment."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.alerting_trusted_public_ip_ranges : can(cidrnetmask(cidr))])
    error_message = "alerting_trusted_public_ip_ranges must contain valid CIDRs."
  }
}

variable "owner" {
  description = "Resource owner/team governance tag."
  type        = string
}

variable "project_label" {
  description = "Business project governance tag."
  type        = string
}

variable "cost_center" {
  description = "Cost allocation governance tag."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all supported Azure resources."
  type        = map(string)
  default     = {}
}

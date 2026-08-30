variable "resource_group_name" {
  description = "Existing workload resource group name from the network module."
  type        = string
}

variable "location" {
  description = "Azure region for AKS, managed identities, and Log Analytics."
  type        = string
}

variable "cluster_name" {
  description = "Name of the private AKS cluster."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,62}$", var.cluster_name))
    error_message = "cluster_name must be 1-63 characters made from letters, numbers, hyphens, or underscores."
  }
}

variable "dns_prefix" {
  description = "Optional AKS DNS prefix. Defaults to cluster_name."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Optional supported AKS Kubernetes version. Leave null for Azure's current default after reviewing the planned version."
  type        = string
  default     = null
}

variable "automatic_upgrade_channel" {
  description = "AKS automatic upgrade channel. Use patch to receive supported patch releases."
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["patch", "rapid", "node-image", "stable", "none"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be patch, rapid, node-image, stable, or none."
  }
}

variable "node_os_upgrade_channel" {
  description = "AKS node OS upgrade channel. NodeImage provides managed node-image refreshes without enabling an unsupported public endpoint."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["Unmanaged", "SecurityPatch", "NodeImage", "None"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be Unmanaged, SecurityPatch, NodeImage, or None."
  }
}

variable "enable_maintenance_windows" {
  description = "Whether Terraform should manage the AKS auto-upgrade and node-OS maintenance windows. Keep enabled for the normal deployment; disable only for a staged apply while the AKS write role propagates."
  type        = bool
  default     = true
}

variable "maintenance_window_frequency" {
  description = "AKS maintenance-window frequency. Azure parity currently uses a daily window."
  type        = string
  default     = "Daily"

  validation {
    condition     = var.maintenance_window_frequency == "Daily"
    error_message = "maintenance_window_frequency must remain Daily for the GCP parity contract."
  }
}

variable "maintenance_window_interval" {
  description = "Interval for the AKS maintenance window. Daily parity uses one interval."
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
  description = "UTC offset for the AKS maintenance window, for example +00:00."
  type        = string
  default     = "+00:00"

  validation {
    condition     = can(regex("^[+-]([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window_utc_offset))
    error_message = "maintenance_window_utc_offset must use a signed HH:MM offset."
  }
}

variable "sku_tier" {
  description = "AKS pricing tier. Standard is selected for production SLA/support features."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID for AKS-managed Entra integration. Defaults to the provider/subscription tenant when null."
  type        = string
  default     = null
}

variable "azure_rbac_admin_group_object_ids" {
  description = "Entra group object IDs granted AKS cluster-admin access through Azure RBAC. Keep this set small and use groups, not individual users."
  type        = set(string)
  default     = []
}

variable "network_scope_id" {
  description = "VNet resource ID on which the AKS control-plane managed identity receives Network Contributor before cluster creation."
  type        = string
}

variable "node_subnet_id" {
  description = "ID of the non-delegated subnet for AKS managed node pools."
  type        = string
}

variable "api_server_subnet_id" {
  description = "ID of the dedicated delegated subnet for AKS API Server VNet Integration."
  type        = string
}

variable "private_dns_zone_id" {
  description = "AKS private DNS zone mode/ID. System uses an AKS-managed private zone and is the secure default."
  type        = string
  default     = "System"
}

variable "pod_cidr" {
  description = "Non-overlapping Azure CNI Overlay pod CIDR. Changing it replaces the cluster."
  type        = string
  default     = "10.4.0.0/14"

  validation {
    condition     = can(cidrnetmask(var.pod_cidr))
    error_message = "pod_cidr must be a valid CIDR."
  }
}

variable "service_cidr" {
  description = "Non-overlapping Kubernetes service CIDR. Changing it replaces the cluster."
  type        = string
  default     = "10.8.0.0/20"

  validation {
    condition     = can(cidrnetmask(var.service_cidr))
    error_message = "service_cidr must be a valid CIDR."
  }
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP inside service_cidr."
  type        = string
  default     = "10.8.0.10"

  validation {
    condition     = can(cidrhost("${var.dns_service_ip}/32", 0))
    error_message = "dns_service_ip must be a valid IPv4 address."
  }
}

variable "system_node_pool" {
  description = "Required regular-capacity system node-pool configuration. Azure names must be 1-12 lowercase alphanumeric characters."
  type = object({
    name                        = string
    vm_size                     = string
    min_size                    = number
    max_size                    = number
    desired_size                = number
    os_disk_size_gb             = optional(number, 100)
    os_disk_type                = optional(string, "Managed")
    max_pods                    = optional(number, 30)
    zones                       = optional(list(string), [])
    node_labels                 = optional(map(string), {})
    temporary_name_for_rotation = optional(string, "sysrotate")
    spot                        = optional(bool, false)
  })

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.system_node_pool.name))
    error_message = "system_node_pool.name must be 1-12 lowercase alphanumeric characters."
  }

  validation {
    condition     = var.system_node_pool.min_size >= 1 && var.system_node_pool.max_size >= var.system_node_pool.min_size && var.system_node_pool.desired_size >= var.system_node_pool.min_size && var.system_node_pool.desired_size <= var.system_node_pool.max_size
    error_message = "system_node_pool sizes must satisfy 1 <= min_size <= desired_size <= max_size."
  }
}

variable "user_node_pools" {
  description = "Optional managed user node pools. Keys are Terraform identifiers; each name must be 1-12 lowercase alphanumeric characters."
  type = map(object({
    name            = string
    vm_size         = string
    min_size        = number
    max_size        = number
    desired_size    = number
    os_disk_size_gb = optional(number, 100)
    os_disk_type    = optional(string, "Managed")
    max_pods        = optional(number, 30)
    zones           = optional(list(string), [])
    node_labels     = optional(map(string), {})
    node_taints     = optional(list(string), [])
    spot            = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      can(regex("^[a-z0-9]{1,12}$", pool.name)) &&
      pool.min_size >= 0 &&
      pool.max_size >= pool.min_size &&
      pool.desired_size >= pool.min_size &&
      pool.desired_size <= pool.max_size
    ])
    error_message = "Each user node pool name must be 1-12 lowercase alphanumeric characters and sizes must satisfy 0 <= min_size <= desired_size <= max_size."
  }
}

variable "node_pool_max_surge" {
  description = "Maximum surge used for managed node-pool upgrades (for example 10% or 1)."
  type        = string
  default     = "10%"
}

variable "log_analytics_workspace_name" {
  description = "Optional Log Analytics workspace name. Defaults to law-<cluster_name>."
  type        = string
  default     = null
}

variable "log_analytics_retention_in_days" {
  description = "Log Analytics retention period for Container Insights data."
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_in_days >= 30 && var.log_analytics_retention_in_days <= 730
    error_message = "log_analytics_retention_in_days must be between 30 and 730."
  }
}

variable "enable_azure_monitor_metrics" {
  description = "Enable Azure Monitor managed Prometheus metrics in addition to Container Insights."
  type        = bool
  default     = false
}

variable "azure_monitor_metrics_annotations_allowed" {
  description = "Optional comma-separated Prometheus annotations allowlist for Azure Monitor metrics."
  type        = string
  default     = null
}

variable "azure_monitor_metrics_labels_allowed" {
  description = "Optional comma-separated Prometheus labels allowlist for Azure Monitor metrics."
  type        = string
  default     = null
}

variable "acr_id" {
  description = "Optional ACR resource ID. When set, the AKS kubelet identity receives the configured pull role."
  type        = string
  default     = null
}

variable "acr_pull_role_definition_name" {
  description = "ACR role assigned to the kubelet identity. AcrPull is suitable for non-ABAC registries; use the repository-reader role/condition selected by the future ACR module for ABAC registries."
  type        = string
  default     = "AcrPull"
}

variable "environment" {
  description = "Deployment environment used for governance tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
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
  description = "Additional tags to apply to all supported Azure resources. Required governance tags take precedence."
  type        = map(string)
  default     = {}
}

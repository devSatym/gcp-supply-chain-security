variable "resource_group_name" {
  description = "Name of the Azure workload resource group created by this module."
  type        = string
}

variable "location" {
  description = "Azure region for all network resources."
  type        = string
}

variable "vnet_name" {
  description = "Name of the workload virtual network."
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR ranges assigned to the workload VNet. They must not overlap AKS Overlay pod/service CIDRs."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.vnet_address_space) > 0 && alltrue([for cidr in var.vnet_address_space : can(cidrnetmask(cidr))])
    error_message = "vnet_address_space must contain one or more valid CIDRs."
  }
}

variable "dns_servers" {
  description = "Optional custom DNS server IPs for the VNet. Leave empty to use Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "aks_nodes_subnet_name" {
  description = "Name of the non-delegated AKS node-pool subnet."
  type        = string
  default     = "snet-aks-nodes"
}

variable "aks_nodes_subnet_address_prefixes" {
  description = "Address prefixes for AKS VMSS node pools."
  type        = list(string)
  default     = ["10.0.0.0/20"]

  validation {
    condition     = alltrue([for cidr in var.aks_nodes_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "aks_nodes_subnet_address_prefixes must contain valid CIDRs."
  }
}

variable "aks_api_server_subnet_name" {
  description = "Name of the dedicated delegated subnet for AKS API Server VNet Integration."
  type        = string
  default     = "snet-aks-api-server"
}

variable "aks_api_server_subnet_address_prefixes" {
  description = "Address prefixes for the AKS API-server subnet. Azure requires at least a /28."
  type        = list(string)
  default     = ["10.0.16.0/28"]

  validation {
    condition     = alltrue([for cidr in var.aks_api_server_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "aks_api_server_subnet_address_prefixes must contain valid CIDRs."
  }
}

variable "private_endpoints_subnet_name" {
  description = "Name of the subnet reserved for Azure Private Endpoints."
  type        = string
  default     = "snet-private-endpoints"
}

variable "private_endpoints_subnet_address_prefixes" {
  description = "Address prefixes for private endpoints used by later ACR, Key Vault, Event Hubs, and storage modules."
  type        = list(string)
  default     = ["10.0.32.0/24"]

  validation {
    condition     = alltrue([for cidr in var.private_endpoints_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "private_endpoints_subnet_address_prefixes must contain valid CIDRs."
  }
}

variable "functions_subnet_name" {
  description = "Name of the delegated subnet for later Azure Functions VNet Integration."
  type        = string
  default     = "snet-functions"
}

variable "functions_subnet_address_prefixes" {
  description = "Address prefixes for Azure Functions VNet Integration."
  type        = list(string)
  default     = ["10.0.48.0/24"]

  validation {
    condition     = alltrue([for cidr in var.functions_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "functions_subnet_address_prefixes must contain valid CIDRs."
  }
}

variable "private_runner_subnet_name" {
  description = "Name of the isolated subnet used only by the private GitHub Actions runner."
  type        = string
  default     = "snet-ci-runner"
}

variable "private_runner_subnet_address_prefixes" {
  description = "Address prefixes for the private GitHub Actions runner subnet."
  type        = list(string)
  default     = ["10.0.64.0/24"]

  validation {
    condition     = alltrue([for cidr in var.private_runner_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "private_runner_subnet_address_prefixes must contain valid CIDRs."
  }
}

variable "attach_nat_gateway_to_private_runner" {
  description = "Whether the private runner subnet uses the controlled NAT Gateway for outbound HTTPS-only access."
  type        = bool
  default     = true
}

variable "nat_gateway_idle_timeout_in_minutes" {
  description = "TCP idle timeout for the NAT Gateway."
  type        = number
  default     = 10

  validation {
    condition     = var.nat_gateway_idle_timeout_in_minutes >= 4 && var.nat_gateway_idle_timeout_in_minutes <= 120
    error_message = "nat_gateway_idle_timeout_in_minutes must be between 4 and 120."
  }
}

variable "attach_nat_gateway_to_functions" {
  description = "Whether the Functions VNet-integration subnet shares the controlled NAT Gateway egress."
  type        = bool
  default     = true
}

variable "private_dns_zone_names" {
  description = "Private Link DNS zones created and linked to the VNet for later modules. AKS uses its managed System zone by default."
  type        = set(string)
  default = [
    "privatelink.azurecr.io",
    "privatelink-data.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.servicebus.windows.net",
    "privatelink.vaultcore.azure.net",
  ]
}

variable "enable_flow_logs" {
  description = "Enable VNet flow logs. Requires Network Watcher support and permissions in the selected subscription."
  type        = bool
  default     = false
}

variable "flow_logs_storage_account_name" {
  description = "Globally unique dedicated StorageV2 account name for VNet flow logs. Required only when enable_flow_logs is true."
  type        = string
  default     = null
}

variable "flow_logs_storage_account_replication_type" {
  description = "Replication SKU for the dedicated flow-log storage account."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.flow_logs_storage_account_replication_type)
    error_message = "flow_logs_storage_account_replication_type must be a supported standard StorageV2 replication SKU."
  }
}

variable "flow_logs_retention_days" {
  description = "Retention period for VNet flow logs in the dedicated storage account."
  type        = number
  default     = 30

  validation {
    condition     = var.flow_logs_retention_days >= 1 && var.flow_logs_retention_days <= 365
    error_message = "flow_logs_retention_days must be between 1 and 365."
  }
}

variable "owner_ssh_allow_cidr" {
  description = "Optional single operator CIDR allowed to SSH to AKS nodes (jump-host access). Null disables the rule."
  type        = string
  default     = null
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

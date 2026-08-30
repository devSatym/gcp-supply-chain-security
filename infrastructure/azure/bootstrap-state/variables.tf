variable "resource_group_name" {
  description = "Name of the dedicated resource group that holds only Terraform state resources."
  type        = string
}

variable "location" {
  description = "Azure region for the state resource group and storage account."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique Azure Storage account name (3-24 lowercase letters and digits)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must contain 3-24 lowercase letters or digits."
  }
}

variable "container_name" {
  description = "Private Blob container that stores Terraform state."
  type        = string
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])?$", var.container_name))
    error_message = "container_name must be a valid 3-63 character lowercase Blob container name."
  }
}

variable "state_key" {
  description = "Suggested Blob key for the Azure production environment state. This module does not initialize its own backend."
  type        = string
  default     = "azure-supply-chain-security/prod.terraform.tfstate"

  validation {
    condition     = endswith(var.state_key, ".tfstate")
    error_message = "state_key must end in .tfstate."
  }
}

variable "account_replication_type" {
  description = "Replication SKU for state storage. Choose a SKU supported by the selected location."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "account_replication_type must be a supported standard StorageV2 replication SKU."
  }
}

variable "public_network_access_enabled" {
  description = "Whether public network access to the state account is enabled. The firewall remains deny-by-default in either case."
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Create a Blob Private Endpoint for the state account after the workload VNet and private DNS zone exist."
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Owner-supplied subnet resource ID for the state Blob Private Endpoint. Required when enabled."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "Owner-supplied privatelink.blob.core.windows.net zone resource ID. Required when enabled."
  type        = string
  default     = null
}

variable "allowed_ip_ranges" {
  description = "Trusted public runner egress CIDRs allowed through the state account firewall when public access is enabled."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_ip_ranges : can(cidrnetmask(cidr))])
    error_message = "Each allowed_ip_ranges value must be a valid CIDR."
  }
}

variable "allowed_subnet_ids" {
  description = "Trusted subnet resource IDs allowed through the state account firewall."
  type        = set(string)
  default     = []
}

variable "blob_soft_delete_retention_days" {
  description = "Number of days deleted state blobs remain recoverable."
  type        = number
  default     = 30

  validation {
    condition     = var.blob_soft_delete_retention_days >= 1 && var.blob_soft_delete_retention_days <= 365
    error_message = "blob_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Number of days deleted state containers remain recoverable."
  type        = number
  default     = 30

  validation {
    condition     = var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365
    error_message = "container_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "state_operator_principal_ids" {
  description = "Entra object IDs for Terraform operators/CI identities that require Blob Data Contributor on this state account. Include the bootstrap caller unless it already has this role."
  type        = set(string)
  default     = []
}

variable "environment" {
  description = "Deployment environment used for governance tags."
  type        = string
  default     = "prod"

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
  description = "Business project governance tag, distinct from Azure subscription identifiers."
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

check "private_endpoint_inputs" {
  assert {
    condition = !var.enable_private_endpoint || (
      var.private_endpoint_subnet_id != null && trimspace(var.private_endpoint_subnet_id) != "" &&
      var.private_dns_zone_id != null && trimspace(var.private_dns_zone_id) != ""
    )
    error_message = "private_endpoint_subnet_id and private_dns_zone_id are required when enable_private_endpoint is true."
  }
}

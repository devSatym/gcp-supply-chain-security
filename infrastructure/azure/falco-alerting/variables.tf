variable "resource_group_name" {
  description = "Resource group containing the alerting resources."
  type        = string
}

variable "location" {
  description = "Azure region for the alerting resources."
  type        = string
}

variable "name_prefix" {
  description = "Lowercase Azure-safe prefix. It must leave room for globally unique Key Vault and Storage Account suffixes."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,14}$", var.name_prefix))
    error_message = "name_prefix must be 3-15 lowercase alphanumeric characters beginning with a letter."
  }
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL exported by AKS for workload identity federation."
  type        = string
}

variable "falcosidekick_service_account_subject" {
  description = "AKS service-account subject trusted by the Falcosidekick UAMI."
  type        = string
  default     = "system:serviceaccount:falco-system:falco-falcosidekick"
}

variable "discord_webhook_url" {
  description = "Discord incoming webhook URL. Pass it through TF_VAR_discord_webhook_url; it is sent using a write-only Key Vault field. Leave empty only while alerting is disabled by the calling root."
  type        = string
  sensitive   = true

  validation {
    condition     = var.discord_webhook_url == "" || startswith(var.discord_webhook_url, "https://discord.com/api/webhooks/")
    error_message = "discord_webhook_url must be empty (alerting disabled) or a Discord incoming-webhook URL."
  }
}

variable "discord_webhook_secret_version" {
  description = "Non-secret version counter for the write-only Discord webhook secret. Increment it whenever the URL rotates."
  type        = number
  default     = 1

  validation {
    condition     = var.discord_webhook_secret_version >= 1 && floor(var.discord_webhook_secret_version) == var.discord_webhook_secret_version
    error_message = "discord_webhook_secret_version must be a positive integer."
  }
}

variable "discord_webhook_secret_expiration_date" {
  description = "UTC expiration for the write-only Discord webhook secret, in YYYY-MM-DDTHH:MM:SSZ format. It is required by the production root whenever runtime alerting is enabled."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.discord_webhook_secret_expiration_date == null || can(formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", var.discord_webhook_secret_expiration_date))
    error_message = "discord_webhook_secret_expiration_date must be a UTC timestamp such as 2030-01-01T00:00:00Z."
  }
}

variable "eventhub_name" {
  description = "Name of the Event Hub that receives Falco alerts."
  type        = string
  default     = "falco-alerts"
}

variable "minimum_priority" {
  description = "Lowest Falco priority forwarded to Discord."
  type        = string
  default     = "notice"

  validation {
    condition = contains(
      ["emergency", "alert", "critical", "error", "warning", "notice", "informational", "debug"],
      lower(var.minimum_priority),
    )
    error_message = "minimum_priority must be a Falco priority."
  }
}

variable "function_source_dir" {
  description = "Optional local path to the Azure Functions source directory."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default     = {}
}

variable "public_network_access_enabled" {
  description = "Whether Event Hubs, Key Vault, and the Function storage account accept public network access. Set false from the environment root only after the private endpoints and private DNS exist."
  type        = bool
  default     = true
}

variable "trusted_public_ip_ranges" {
  description = "Public Terraform-runner CIDRs allowed to set the Discord secret while Key Vault public access is enabled. Leave empty only when private endpoint access is used."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.trusted_public_ip_ranges : can(cidrnetmask(cidr))])
    error_message = "trusted_public_ip_ranges must contain valid CIDRs."
  }
}

variable "virtual_network_subnet_id" {
  description = "Delegated subnet ID used for Azure Function VNet integration. Required when public network access is disabled."
  type        = string
  default     = null
  nullable    = true
}

check "private_function_networking" {
  assert {
    condition     = var.public_network_access_enabled || (var.virtual_network_subnet_id != null && trimspace(var.virtual_network_subnet_id) != "")
    error_message = "virtual_network_subnet_id is required when alerting service public network access is disabled."
  }
}

check "public_key_vault_writer_access" {
  assert {
    condition     = !var.public_network_access_enabled || length(var.trusted_public_ip_ranges) > 0
    error_message = "trusted_public_ip_ranges is required while Key Vault public access is enabled so Terraform can set the write-only Discord secret without opening the vault broadly."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for Falco and Falcosidekick."
  type        = string
  default     = "falco-system"
}

variable "falco_helm_version" {
  description = "Version of the falcosecurity/falco Helm chart."
  type        = string
  default     = "9.1.0"
}

variable "falco_driver" {
  description = "Falco kernel instrumentation driver. modern_ebpf avoids in-cluster kernel-module builds."
  type        = string
  default     = "modern_ebpf"

  validation {
    condition     = contains(["modern_ebpf", "ebpf", "kmod"], var.falco_driver)
    error_message = "falco_driver must be one of: modern_ebpf, ebpf, kmod."
  }
}

variable "enable_falcosidekick" {
  description = "Whether to deploy Falcosidekick for alert routing."
  type        = bool
  default     = true
}

variable "eventhub_name" {
  description = "Azure Event Hub to receive Falco alerts. Leave null to disable this output."
  type        = string
  default     = null
}

variable "eventhub_namespace_fqdn" {
  description = "Fully qualified Event Hubs namespace, for example example.servicebus.windows.net."
  type        = string
  default     = null
}

variable "falcosidekick_client_id" {
  description = "Client ID of the Falcosidekick user-assigned managed identity. Leave null while alerting is disabled."
  type        = string
  default     = null
}

variable "minimum_priority" {
  description = "Lowest Falco priority sent to Event Hubs."
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

variable "custom_rules_yaml" {
  description = "Optional raw YAML content for a cluster-specific Falco rules file."
  type        = string
  default     = ""
}

variable "resources" {
  description = "Resource requests and limits for Falco pods."
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1024Mi"
    }
  }
}

variable "labels" {
  description = "Additional namespace labels."
  type        = map(string)
  default = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "supply-chain-security"
  }
}

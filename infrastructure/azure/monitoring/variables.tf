variable "resource_group_name" {
  description = "Resource group containing the private AKS and ACR resources that emit diagnostics."
  type        = string
}

variable "location" {
  description = "Azure region for the Log Analytics workspace."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for the Log Analytics workspace name."
  type        = string
}

variable "aks_cluster_id" {
  description = "Resource ID of the private AKS cluster whose logs and metrics are collected."
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the Azure Container Registry whose logs and metrics are collected."
  type        = string
}

variable "retention_in_days" {
  description = "Workspace retention in days for the complete baseline; paid long-term retention is an owner decision."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "tags" {
  description = "Tags applied to the Log Analytics workspace."
  type        = map(string)
  default     = {}
}

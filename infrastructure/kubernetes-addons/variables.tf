variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster these add-ons are deployed to"
  type        = string
}

variable "enable_metrics_server" {
  description = "Deploy a separate metrics-server via Helm. Leave false — GKE Standard clusters ship a built-in metrics-server in kube-system automatically, and installing a second one collides with it (ServiceAccount ownership conflict). Only set true if you've explicitly disabled/removed the built-in one."
  type        = bool
  default     = false
}

variable "metrics_server_chart_version" {
  description = "Helm chart version for metrics-server"
  type        = string
  default     = "3.12.1"
}

variable "enable_external_dns" {
  description = "Deploy External DNS wired to Cloud DNS via Workload Identity"
  type        = bool
  default     = true
}

variable "external_dns_chart_version" {
  description = "Helm chart version for external-dns"
  type        = string
  default     = "1.14.5"
}

variable "dns_domain_filter" {
  description = "Domain External DNS is allowed to manage records for"
  type        = string
  default     = ""
}

variable "external_dns_policy" {
  description = "External DNS record management policy"
  type        = string
  default     = "upsert-only"

  validation {
    condition     = contains(["sync", "upsert-only"], var.external_dns_policy)
    error_message = "external_dns_policy must be 'sync' or 'upsert-only'."
  }
}

variable "enable_node_auto_provisioning" {
  description = "Informational flag only — actual Node Auto-Provisioning is configured in the gke module's cluster_autoscaling block."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Resource owner/team label (required governance label)"
  type        = string
}

variable "project_label" {
  description = "Business project name label (required governance label). Distinct from project_id."
  type        = string
}

variable "cost_center" {
  description = "Cost allocation label (required governance label)"
  type        = string
}

variable "labels" {
  description = "A map of additional labels to add to namespaced resources"
  type        = map(string)
  default     = {}
}

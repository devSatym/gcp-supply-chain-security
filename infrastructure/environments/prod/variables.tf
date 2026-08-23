variable "project_id" {
  description = "GCP project ID that will own this deployment."
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "name" {
  description = "Base resource name prefix, used by the vpc module"
  type        = string
  default     = "core"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Resource owner/team label"
  type        = string
}

variable "project_label" {
  description = "Business project name label (distinct from project_id)"
  type        = string
}

variable "cost_center" {
  description = "Cost allocation label"
  type        = string
}

variable "private_subnets" {
  description = "Map of private subnets for GKE nodes"
  type = map(object({
    cidr_block          = string
    pods_cidr_block     = string
    services_cidr_block = string
  }))
  default = {
    main = {
      cidr_block          = "10.0.0.0/20"
      pods_cidr_block     = "10.4.0.0/14"
      services_cidr_block = "10.8.0.0/20"
    }
  }
}

variable "public_subnets" {
  description = "Map of public subnets"
  type = map(object({
    cidr_block = string
  }))
  default = {}
}

variable "primary_subnet_key" {
  description = "Key within private_subnets that the GKE cluster's nodes live in"
  type        = string
  default     = "main"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "prod-cluster"
}

variable "cluster_version" {
  description = "Kubernetes master version, or 'latest'"
  type        = string
  default     = "latest"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "node_locations" {
  description = "Optional list of zones to pin GKE nodes to (avoids zones reporting GCE_STOCKOUT)"
  type        = list(string)
  default     = []
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the GKE master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "node_pools" {
  description = "Map of GKE node pool configurations. min_size, max_size, and desired_size are total nodes across the pool, not nodes per zone."
  type = map(object({
    machine_type = string
    min_size     = number
    max_size     = number
    desired_size = number
    disk_size_gb = optional(number, 100)
    disk_type    = optional(string, "pd-balanced")
    spot         = optional(bool, false)
  }))
  default = {
    main = {
      machine_type = "e2-standard-4"
      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
  }
}

variable "dns_domain_filter" {
  description = "Domain External DNS is allowed to manage records for"
  type        = string
  default     = ""
}

variable "enable_metrics_server" {
  description = "Deploy a separate metrics-server via Helm. Leave false — GKE ships its own."
  type        = bool
  default     = false
}

variable "enable_external_dns" {
  description = "Deploy ExternalDNS and grant it Cloud DNS permissions. Keep false unless this project owns a DNS zone."
  type        = bool
  default     = false
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus. Disabled by default because observability is outside this project's initial scope."
  type        = bool
  default     = false
}

variable "gar_repository_id" {
  description = "Artifact Registry Docker repository ID for the signed application image."
  type        = string
  default     = "supply-chain-security"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.gar_repository_id))
    error_message = "gar_repository_id must be a valid Artifact Registry repository ID."
  }
}

variable "github_repository" {
  description = "Canonical GitHub repository trusted by the CI Workload Identity provider."
  type        = string
  default     = "devSatym/gcp-supply-chain-security"

  validation {
    condition     = var.github_repository == "devSatym/gcp-supply-chain-security"
    error_message = "Only the canonical devSatym/gcp-supply-chain-security repository is trusted."
  }
}

variable "github_wif_pool_id" {
  description = "Dedicated Workload Identity Pool ID for this repository's GitHub Actions federation."
  type        = string
  default     = "supply-chain-github-pool"
}

variable "github_wif_provider_id" {
  description = "OIDC provider ID within github_wif_pool_id."
  type        = string
  default     = "github-provider"
}

variable "enable_runtime_alerting" {
  description = "Create the Falco Pub/Sub to Cloud Function alert path. Requires discord_webhook_url and is disabled until an alert destination is supplied."
  type        = bool
  default     = false
}

variable "discord_webhook_url" {
  description = "Discord incoming webhook URL (Server Settings -> Integrations -> Webhooks). Stored in Secret Manager, never passed as a plain env var."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = !var.enable_runtime_alerting || (var.discord_webhook_url != null && startswith(var.discord_webhook_url, "https://discord.com/api/webhooks/"))
    error_message = "Set a Discord incoming-webhook URL when enable_runtime_alerting is true."
  }
}

variable "enable_legacy_ratify" {
  description = "Retain the imported Gatekeeper/Ratify compatibility resources for historical investigation only. This is intentionally disabled because Kyverno is the admission controller for this project."
  type        = bool
  default     = false
}

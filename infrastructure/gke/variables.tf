variable "project_id" {
  description = "GCP project ID where the cluster will be created"
  type        = string
}

variable "region" {
  description = "GCP region for a regional cluster"
  type        = string
}

variable "zone" {
  description = "GCP zone for a zonal cluster (used when regional = false)"
  type        = string
  default     = null
}

variable "regional" {
  description = "Whether to create a regional (multi-zone, HA control plane) cluster"
  type        = bool
  default     = true
}

variable "node_locations" {
  description = "Optional list of zones to run nodes in (e.g. to avoid a zone reporting GCE_STOCKOUT). Leave empty to let GKE auto-select zones within the region."
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes master version (or 'latest')"
  type        = string
  default     = "latest"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "release_channel must be one of RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "network_self_link" {
  description = "Self link of the VPC network (from the vpc module)"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork to deploy nodes into (from the vpc module)"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
}

variable "enable_private_endpoint" {
  description = "If true, the cluster master's internal IP is used as the endpoint (no public master access)"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master's private network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks allowed to access the Kubernetes master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = false
}

variable "maintenance_start_time" {
  description = "Daily maintenance window start time (HH:MM, UTC)"
  type        = string
  default     = "03:00"
}

variable "node_pools" {
  description = "Map of node pool configurations, keyed by pool name"
  type = map(object({
    machine_type = string
    min_size     = number
    max_size     = number
    desired_size = number
    disk_size_gb = optional(number, 100)
    disk_type    = optional(string, "pd-balanced")
    spot         = optional(bool, false)
  }))
}

variable "node_pool_roles" {
  description = "IAM roles granted to every node pool's service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
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
  description = "A map of additional labels to add to all resources"
  type        = map(string)
  default     = {}
}

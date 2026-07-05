variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region for the VPC subnets, router and NAT"
  type        = string
}

variable "name" {
  description = "Base name used as a prefix on all resources"
  type        = string
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

variable "routing_mode" {
  description = "VPC routing mode"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be REGIONAL or GLOBAL."
  }
}

variable "mtu" {
  description = "Maximum transmission unit for the VPC"
  type        = number
  default     = 1460
}

variable "private_subnets" {
  description = "Map of private subnets (GKE node subnets), keyed by a short name (e.g. 'main')"
  type = map(object({
    cidr_block          = string
    pods_cidr_block     = string
    services_cidr_block = string
  }))
}

variable "public_subnets" {
  description = "Map of public subnets (load balancers, bastion), keyed by a short name"
  type = map(object({
    cidr_block = string
  }))
  default = {}
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs on all subnets"
  type        = bool
  default     = true
}

variable "flow_logs_interval" {
  description = "Aggregation interval for VPC Flow Logs"
  type        = string
  default     = "INTERVAL_5_SEC"
}

variable "flow_logs_sampling" {
  description = "Sampling rate for VPC Flow Logs (0.0 - 1.0)"
  type        = number
  default     = 0.5
}

variable "enable_iap_ssh" {
  description = "Allow SSH via Identity-Aware Proxy TCP forwarding range"
  type        = bool
  default     = true
}

variable "labels" {
  description = "A map of additional labels to add to all resources"
  type        = map(string)
  default     = {}
}

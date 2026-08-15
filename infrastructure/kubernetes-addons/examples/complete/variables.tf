variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "my-gcp-project"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "cluster_name" {
  description = "Existing GKE cluster name"
  type        = string
  default     = "dev-cluster"
}

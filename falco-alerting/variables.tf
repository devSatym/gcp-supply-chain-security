variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Pub/Sub topic and Cloud Function (e.g. europe-west1)."
  type        = string
}

variable "topic_name" {
  description = "Name of the Pub/Sub topic Falcosidekick publishes alerts to."
  type        = string
  default     = "falco-alerts"
}

variable "discord_webhook_url" {
  description = "Discord incoming webhook URL (Server Settings -> Integrations -> Webhooks). Stored in Secret Manager, never passed as a plain env var."
  type        = string
  sensitive   = true
}

variable "min_priority" {
  description = "Minimum Falco alert priority forwarded to Discord (emergency, alert, critical, error, warning, notice, informational, debug). Filters noise before it hits your channel."
  type        = string
  default     = "warning"
}

variable "function_source_dir" {
  description = "Local path to the Cloud Function source (main.py + requirements.txt)."
  type        = string
  default     = null
}

variable "labels" {
  description = "Common labels applied to alerting resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    addon      = "falco-alerting"
  }
}

variable "project_id" {
  description = "GCP project ID where the GKE cluster lives."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster to deploy Falco onto (e.g. prod-cluster)."
  type        = string
}

variable "region" {
  description = "Region of the GKE cluster (e.g. europe-west1)."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Falco and Falcosidekick into."
  type        = string
  default     = "falco-system"
}

variable "falco_helm_version" {
  description = "Version of the falcosecurity/falco Helm chart to install."
  type        = string
  default     = "4.7.4"
}

variable "falco_driver" {
  description = "Falco kernel instrumentation driver. modern_ebpf avoids DaemonSet privileged kernel module builds and works cleanly on GKE COS/Ubuntu nodes."
  type        = string
  default     = "modern_ebpf"

  validation {
    condition     = contains(["modern_ebpf", "ebpf", "kmod"], var.falco_driver)
    error_message = "falco_driver must be one of: modern_ebpf, ebpf, kmod."
  }
}

variable "enable_falcosidekick" {
  description = "Whether to deploy Falcosidekick as the alert routing sidecar/service."
  type        = bool
  default     = true
}

variable "alert_pubsub_topic_id" {
  description = "Full Pub/Sub topic ID (projects/PROJECT/topics/TOPIC) that Falcosidekick should publish alerts to. Leave null to disable the Pub/Sub output."
  type        = string
  default     = null
}

variable "falcosidekick_gsa_email" {
  description = "Email of the GCP service account Falcosidekick uses to publish to Pub/Sub."
  type        = string
}

variable "falcosidekick_gcp_credentials_b64" {
  description = "Base64-encoded JSON key for the falcosidekick_gsa_email service account."
  type        = string
  sensitive   = true
}

variable "custom_rules_yaml" {
  description = "Optional raw YAML content for a custom Falco rules file, tuned against this cluster's own signed/scanned workloads (e.g. alert on any shell exec, since no pod here should ever need one)."
  type        = string
  default     = ""
}

variable "resources" {
  description = "Resource requests/limits for the Falco DaemonSet pods."
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
  description = "Common labels applied to Falco resources, consistent with other addons in this repo."
  type        = map(string)
  default = {
    managed-by = "terraform"
    addon      = "falco"
  }
}

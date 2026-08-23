# ratify-gar-auth.tf
# Retained imported compatibility code for Ratify to authenticate to GAR.
#
# The final deployment uses Kyverno, not Gatekeeper/Ratify. Every resource in
# this file is therefore disabled by default through enable_legacy_ratify.
#
# Context: Ratify (notaryproject/ratify) has no native GCP Workload Identity
# auth provider. Its k8Secrets provider hardcodes a 12-hour credential TTL
# regardless of Secret content freshness, making short-lived GCP OAuth2 tokens
# (~1h expiry) unworkable via CronJob or ESO refresh. A long-lived JSON key is
# the only viable option until upstream adds a GCP auth provider.
#
# See: docs/decisions/ratify-gcp-auth-tradeoff.md in supply-chain-security repo
# Source: pkg/common/oras/authprovider/k8secret_authprovider.go — const secretTimeout = time.Hour * 12

# ---------------------------------------------------------------------------
# Service account
# ---------------------------------------------------------------------------

resource "google_service_account" "ratify_gar_reader" {
  count = var.enable_legacy_ratify ? 1 : 0

  account_id   = "ratify-gar-reader"
  display_name = "Ratify GAR Reader"
  description  = "Minimal read-only access to supply-chain-security GAR repo for Ratify signature verification. Uses a long-lived JSON key due to Ratify k8Secrets 12h credential TTL."
  project      = var.project_id
}

# ---------------------------------------------------------------------------
# IAM — repo-scoped reader only (NOT project-wide artifactregistry.reader)
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "ratify_gar_reader" {
  count = var.enable_legacy_ratify ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = var.gar_repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.ratify_gar_reader[0].email}"
}

# ---------------------------------------------------------------------------
# JSON key
# Stored in Terraform state (GCS bucket, server-side encrypted).
# Use output below to extract and create the k8s Secret — never commit the key.
# Rotate every 90 days: `terraform apply -replace=google_service_account_key.ratify_gar_reader`
# ---------------------------------------------------------------------------

resource "google_service_account_key" "ratify_gar_reader" {
  count = var.enable_legacy_ratify ? 1 : 0

  service_account_id = google_service_account.ratify_gar_reader[0].name
  key_algorithm      = "KEY_ALG_RSA_2048"

  # Prevent accidental destroy — key deletion is immediate and irreversible
  lifecycle {
    prevent_destroy = false # set true after first rotation cycle if preferred
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "ratify_gar_reader_sa_email" {
  description = "Email of the legacy ratify-gar-reader service account, if explicitly enabled."
  value       = try(google_service_account.ratify_gar_reader[0].email, null)
}

output "ratify_gar_reader_key_b64" {
  description = "Base64-encoded JSON key for legacy Ratify only. Null unless explicitly enabled; do not log or commit it."
  value       = try(google_service_account_key.ratify_gar_reader[0].private_key, null)
  sensitive   = true
}

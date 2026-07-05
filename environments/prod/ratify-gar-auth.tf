# ratify-gar-auth.tf
# Creates a minimal, scoped service account for Ratify to authenticate to GAR.
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
  account_id   = "ratify-gar-reader"
  display_name = "Ratify GAR Reader"
  description  = "Minimal read-only access to supply-chain-security GAR repo for Ratify signature verification. Uses a long-lived JSON key due to Ratify k8Secrets 12h credential TTL."
  project      = var.project_id
}

# ---------------------------------------------------------------------------
# IAM — repo-scoped reader only (NOT project-wide artifactregistry.reader)
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "ratify_gar_reader" {
  project    = var.project_id
  location   = var.region
  repository = "supply-chain-security"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.ratify_gar_reader.email}"
}

# ---------------------------------------------------------------------------
# JSON key
# Stored in Terraform state (GCS bucket, server-side encrypted).
# Use output below to extract and create the k8s Secret — never commit the key.
# Rotate every 90 days: `terraform apply -replace=google_service_account_key.ratify_gar_reader`
# ---------------------------------------------------------------------------

resource "google_service_account_key" "ratify_gar_reader" {
  service_account_id = google_service_account.ratify_gar_reader.name
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
  description = "Email of the ratify-gar-reader service account"
  value       = google_service_account.ratify_gar_reader.email
}

output "ratify_gar_reader_key_b64" {
  description = "Base64-encoded JSON key for ratify-gar-reader. Use to create the k8s Secret — do NOT log or commit."
  value       = google_service_account_key.ratify_gar_reader.private_key
  sensitive   = true
}

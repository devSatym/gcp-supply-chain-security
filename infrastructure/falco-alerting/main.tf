# modules/falco-alerting/main.tf
#
# Falco -> Falcosidekick -> Pub/Sub -> Cloud Function -> Discord.
# Event-driven so the alert path has no dependency on the GKE cluster
# staying up once an alert has fired, and so it's demoable end-to-end
# independent of cluster lifecycle (spin up for a demo, tear down after).

resource "google_pubsub_topic" "falco_alerts" {
  name    = var.topic_name
  project = var.project_id
  labels  = var.labels
}

# Discord webhook lives in Secret Manager, not as a Cloud Function env var,
# so it never appears in `terraform plan` output, Cloud Console env var
# listings, or CI logs.
resource "google_secret_manager_secret" "discord_webhook" {
  secret_id = "falco-discord-webhook-url"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "discord_webhook" {
  secret                 = google_secret_manager_secret.discord_webhook.id
  secret_data_wo         = var.discord_webhook_url
  secret_data_wo_version = var.discord_webhook_secret_version
}

# Least-privilege runtime SA for the function: only Secret Manager
# accessor for this one secret, no broad project-level roles.
resource "google_service_account" "discord_notifier" {
  account_id   = "falco-discord-notifier"
  display_name = "Falco Discord notifier Cloud Function"
  project      = var.project_id
}

resource "google_secret_manager_secret_iam_member" "discord_notifier_secret_access" {
  secret_id = google_secret_manager_secret.discord_webhook.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_notifier.email}"
}

resource "google_pubsub_topic_iam_member" "discord_notifier_subscriber" {
  topic  = google_pubsub_topic.falco_alerts.name
  role   = "roles/pubsub.subscriber"
  member = "serviceAccount:${google_service_account.discord_notifier.email}"
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-falco-function-source"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  labels                      = var.labels
}

locals {
  function_source_dir = coalesce(var.function_source_dir, "${path.module}/functions/discord-notifier")
}
data "archive_file" "discord_notifier_source" {
  type        = "zip"
  source_dir  = local.function_source_dir
  output_path = "${path.module}/.build/discord-notifier.zip"

}

resource "google_storage_bucket_object" "discord_notifier_source" {
  name   = "discord-notifier-${data.archive_file.discord_notifier_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.discord_notifier_source.output_path
}

resource "google_cloudfunctions2_function" "discord_notifier" {
  name     = "falco-discord-notifier"
  project  = var.project_id
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "notify_discord"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.discord_notifier_source.name
      }
    }
  }

  service_config {
    max_instance_count             = 5
    min_instance_count             = 0
    available_memory               = "256Mi"
    timeout_seconds                = 30
    service_account_email          = google_service_account.discord_notifier.email
    all_traffic_on_latest_revision = true

    environment_variables = {
      DISCORD_WEBHOOK_SECRET_NAME = google_secret_manager_secret.discord_webhook.secret_id
      GCP_PROJECT                 = var.project_id
      MIN_PRIORITY                = var.min_priority
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.falco_alerts.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  labels = var.labels
}

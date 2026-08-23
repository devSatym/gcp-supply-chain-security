# environments/prod/falco-alerting.tf
#
# Pub/Sub -> Cloud Function -> Discord alerting pipeline for Falco.
# falcosidekick (deployed by the falco module) publishes to the topic
# created here using a GKE Workload Identity-bound service account.

module "falco_alerting" {
  count = var.enable_runtime_alerting ? 1 : 0

  source = "../../falco-alerting"

  project_id          = var.project_id
  region              = var.region
  discord_webhook_url = var.discord_webhook_url
  min_priority        = "notice"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "falcosidekick" {
  count = var.enable_runtime_alerting ? 1 : 0

  account_id   = "falcosidekick"
  display_name = "Falcosidekick alert publisher"
  project      = var.project_id
}

resource "google_pubsub_topic_iam_member" "falcosidekick_publisher" {
  count = var.enable_runtime_alerting ? 1 : 0

  topic  = module.falco_alerting[0].pubsub_topic_id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.falcosidekick[0].email}"
}

resource "google_service_account_iam_member" "falcosidekick_workload_identity" {
  count = var.enable_runtime_alerting ? 1 : 0

  service_account_id = google_service_account.falcosidekick[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[falco-system/falco-falcosidekick]"
}

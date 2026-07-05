# environments/prod/falco-alerting.tf
#
# Pub/Sub -> Cloud Function -> Discord alerting pipeline for Falco.
# falcosidekick (deployed by the falco module) publishes to the topic
# created here using the service account below.

module "falco_alerting" {
  source = "../../falco-alerting"

  project_id          = var.project_id
  region              = var.region
  discord_webhook_url = var.discord_webhook_url
  min_priority        = "notice"
}

resource "google_service_account" "falcosidekick" {
  account_id   = "falcosidekick"
  display_name = "Falcosidekick alert publisher"
  project      = var.project_id
}

resource "google_pubsub_topic_iam_member" "falcosidekick_publisher" {
  topic  = module.falco_alerting.pubsub_topic_id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.falcosidekick.email}"
}

resource "google_service_account_key" "falcosidekick" {
  service_account_id = google_service_account.falcosidekick.name
  key_algorithm      = "KEY_ALG_RSA_2048"
}
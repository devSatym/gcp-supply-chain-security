output "pubsub_topic_id" {
  description = "Full Pub/Sub topic ID. Pass this into the falco module's alert_pubsub_topic_id variable."
  value       = google_pubsub_topic.falco_alerts.id
}

output "function_name" {
  description = "Name of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.discord_notifier.name
}

output "function_service_account" {
  description = "Least-privilege service account the function runs as."
  value       = google_service_account.discord_notifier.email
}

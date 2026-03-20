output "trigger_id" {
  value       = google_cloudbuild_trigger.trigger.trigger_id
  description = "Cloud Build trigger ID"
}

output "trigger_name" {
  value       = google_cloudbuild_trigger.trigger.name
  description = "Cloud Build trigger name"
}

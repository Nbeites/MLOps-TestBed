resource "google_cloudbuild_trigger" "trigger" {
  project        = var.project_id
  name           = var.trigger_name
  description    = var.description
  filename       = var.filename
  substitutions  = var.substitutions
  included_files = var.included_files
  ignored_files  = var.ignored_files

  github {
    owner = var.repo_owner
    name  = var.repo_name

    push {
      branch = var.branch_regex
    }
  }
}

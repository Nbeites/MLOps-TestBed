terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the GCS bucket"
  type        = string
}

variable "location" {
  description = "Bucket location (region)"
  type        = string
  default     = "europe-west1"
}

resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
}

output "bucket_name" {
  description = "Name of the created bucket"
  value       = google_storage_bucket.this.name
}


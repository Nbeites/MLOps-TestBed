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

variable "region" {
  description = "Cloud Run region"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "image" {
  description = "Container image to deploy"
  type        = string
}

variable "model_bucket" {
  description = "Model bucket name"
  type        = string
}

variable "model_blob" {
  description = "Model path/blob inside the bucket"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 1
}

resource "google_cloud_run_v2_service" "this" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.image

      env {
        name  = "MODEL_BUCKET"
        value = var.model_bucket
      }

      env {
        name  = "MODEL_BLOB"
        value = var.model_blob
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

output "service_name" {
  description = "Deployed Cloud Run service name"
  value       = google_cloud_run_v2_service.this.name
}


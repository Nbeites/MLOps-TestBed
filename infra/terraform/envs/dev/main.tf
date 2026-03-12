terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID for dev"
  type        = string
}

variable "region" {
  description = "Region for dev resources"
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Cloud Run service name for dev"
  type        = string
  default     = "iris-mlops-api-dev"
}

variable "image" {
  description = "Container image to deploy for dev"
  type        = string
}

module "model_bucket" {
  source     = "../../modules/gcs_bucket"
  project_id = var.project_id
  name       = "${var.project_id}-iris-mlops-demo-dev"
  location   = var.region
}

module "cloud_run" {
  source       = "../../modules/cloud_run_service"
  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = var.image

  model_bucket = module.model_bucket.bucket_name
  model_blob   = "models/iris/latest/model.joblib"

  min_instances = 0
  max_instances = 1
}


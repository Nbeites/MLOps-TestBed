variable "project_id" {
  description = "GCP project id where trigger is created"
  type        = string
}

variable "trigger_name" {
  description = "Name of the Cloud Build trigger"
  type        = string
}

variable "description" {
  description = "Description of the trigger"
  type        = string
  default     = "Managed by Terraform/Terragrunt"
}

variable "repo_owner" {
  description = "GitHub org/user owner"
  type        = string
}

variable "repo_name" {
  description = "GitHub repo name"
  type        = string
}

variable "branch_regex" {
  description = "Regex branch filter for push events"
  type        = string
}

variable "filename" {
  description = "Cloud Build config file path"
  type        = string
  default     = "cloudbuild.yaml"
}

variable "substitutions" {
  description = "Substitutions passed to Cloud Build"
  type        = map(string)
  default     = {}
}

variable "included_files" {
  description = "Optional include file globs"
  type        = list(string)
  default     = []
}

variable "ignored_files" {
  description = "Optional ignored file globs"
  type        = list(string)
  default     = []
}

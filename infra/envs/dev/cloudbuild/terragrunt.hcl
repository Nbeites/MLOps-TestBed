terraform {
  source = "../../../terraform/modules/cloudbuild_trigger"
}

inputs = {
  project_id   = "YOUR_DEV_PROJECT_ID"
  trigger_name = "mlops-dev-trigger"
  description  = "DEV trigger for develop branch"

  repo_owner   = "YOUR_GITHUB_OWNER"
  repo_name    = "MLOps-TestBed"
  branch_regex = "^develop$"
  filename     = "cloudbuild.yaml"

  substitutions = {
    _ENV           = "dev"
    _REGION        = "europe-west1"
    _SERVICE_NAME  = "iris-mlops-api-dev"
    _IMAGE         = "gcr.io/YOUR_DEV_PROJECT_ID/iris-mlops-api-dev:$SHORT_SHA"
    _MODEL_BUCKET  = "YOUR_DEV_PROJECT_ID-iris-mlops-demo-dev"
    _MODEL_VERSION = "$SHORT_SHA"
  }
}

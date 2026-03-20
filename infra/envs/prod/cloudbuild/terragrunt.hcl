terraform {
  source = "../../../terraform/modules/cloudbuild_trigger"
}

inputs = {
  project_id   = "YOUR_PROD_PROJECT_ID"
  trigger_name = "mlops-prod-trigger"
  description  = "PROD trigger for main branch"

  repo_owner   = "YOUR_GITHUB_OWNER"
  repo_name    = "MLOps-TestBed"
  branch_regex = "^main$"
  filename     = "cloudbuild.yaml"

  substitutions = {
    _ENV           = "prod"
    _REGION        = "europe-west1"
    _SERVICE_NAME  = "iris-mlops-api-prod"
    _IMAGE         = "gcr.io/YOUR_PROD_PROJECT_ID/iris-mlops-api-prod:$SHORT_SHA"
    _MODEL_BUCKET  = "YOUR_PROD_PROJECT_ID-iris-mlops-demo-prod"
    _MODEL_VERSION = "$SHORT_SHA"
  }
}

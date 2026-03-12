terraform {
  source = "../../terraform/envs/dev"
}

inputs = {
  project_id  = "YOUR_DEV_PROJECT_ID"
  region      = "europe-west1"
  service_name = "iris-mlops-api-dev"
  # Image should usually match what Cloud Build produces, e.g. gcr.io/PROJECT_ID/iris-mlops-api:latest
  image       = "gcr.io/YOUR_DEV_PROJECT_ID/iris-mlops-api:latest"
}


# Quickstart: Full Command Runbook (No Hidden Steps)

This is a strict, explicit command sequence for a new engineer.

## 0) Open Cloud Shell and clone repo

```bash
git clone https://github.com/<YOUR_GITHUB_OWNER>/MLOps-TestBed.git
cd MLOps-TestBed
```

## 1) Set all variables once

```bash
export DEV_PROJECT_ID="<YOUR_DEV_PROJECT_ID>"
export PROD_PROJECT_ID="<YOUR_PROD_PROJECT_ID>"
export DEV_REGION="europe-west1"
export PROD_REGION="europe-west1"
export GITHUB_OWNER="<YOUR_GITHUB_OWNER>"
export REPO_NAME="MLOps-TestBed"
```

If DEV and PROD are the same project, set both IDs to the same value.

## 2) Authenticate and set ADC

```bash
gcloud auth login
gcloud auth application-default login
```

## 3) Enable required Google APIs (both projects)

```bash
for PROJECT in "$DEV_PROJECT_ID" "$PROD_PROJECT_ID"; do
  gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    storage.googleapis.com \
    iam.googleapis.com \
    --project "$PROJECT"
done
```

## 4) Grant IAM to Cloud Build service accounts (both projects)

`cloudbuild.yaml` trains (GCS), pushes image, and deploys to Cloud Run. The Cloud Build service account needs these permissions.

```bash
for PROJECT in "$DEV_PROJECT_ID" "$PROD_PROJECT_ID"; do
  PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
  CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/run.admin"

  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/iam.serviceAccountUser"

  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/storage.admin"

  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/artifactregistry.writer"
done
```

## 5) Fill DEV and PROD Terragrunt files

Edit:

- `infra/envs/dev/cloudbuild/terragrunt.hcl`
- `infra/envs/prod/cloudbuild/terragrunt.hcl`

Replace all placeholders:

- `YOUR_DEV_PROJECT_ID`
- `YOUR_PROD_PROJECT_ID`
- `YOUR_GITHUB_OWNER`

Optional: adjust `_SERVICE_NAME`, `_MODEL_BUCKET`, `_REGION`.

## 6) Create DEV trigger

```bash
gcloud config set project "$DEV_PROJECT_ID"
cd infra/envs/dev/cloudbuild
terragrunt init
terragrunt apply -auto-approve
cd ../../../..
```

Verify DEV trigger:

```bash
gcloud builds triggers list --project "$DEV_PROJECT_ID"
```

## 7) Create PROD trigger

```bash
gcloud config set project "$PROD_PROJECT_ID"
cd infra/envs/prod/cloudbuild
terragrunt init
terragrunt apply -auto-approve
cd ../../../..
```

Verify PROD trigger:

```bash
gcloud builds triggers list --project "$PROD_PROJECT_ID"
```

## 8) Validate pipeline manually before GitHub push (optional but recommended)

DEV manual build:

```bash
gcloud config set project "$DEV_PROJECT_ID"
gcloud builds submit --config cloudbuild.yaml .
```

PROD manual build:

```bash
gcloud config set project "$PROD_PROJECT_ID"
gcloud builds submit --config cloudbuild.yaml .
```

## 9) Push to `develop` (deploy DEV automatically)

```bash
git checkout develop
git add .
git commit -m "test: trigger dev pipeline"
git push origin develop
```

Watch DEV build:

```bash
gcloud config set project "$DEV_PROJECT_ID"
gcloud builds list --project "$DEV_PROJECT_ID" --limit=5
BUILD_ID="$(gcloud builds list --project "$DEV_PROJECT_ID" --limit=1 --format='value(id)')"
gcloud builds log "$BUILD_ID" --project "$DEV_PROJECT_ID"
```

## 10) Push to `main` (deploy PROD automatically)

```bash
git checkout main
git merge --no-ff develop -m "release: promote develop to main"
git push origin main
```

Watch PROD build:

```bash
gcloud config set project "$PROD_PROJECT_ID"
gcloud builds list --project "$PROD_PROJECT_ID" --limit=5
BUILD_ID="$(gcloud builds list --project "$PROD_PROJECT_ID" --limit=1 --format='value(id)')"
gcloud builds log "$BUILD_ID" --project "$PROD_PROJECT_ID"
```

## 11) Get Cloud Run URLs and smoke test

DEV:

```bash
gcloud config set project "$DEV_PROJECT_ID"
gcloud run services list --region "$DEV_REGION" --project "$DEV_PROJECT_ID"
DEV_URL="$(gcloud run services describe iris-mlops-api-dev --region "$DEV_REGION" --project "$DEV_PROJECT_ID" --format='value(status.url)')"
echo "$DEV_URL"
curl -X POST "${DEV_URL}/predict" \
  -H "Content-Type: application/json" \
  -d '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}'
```

PROD:

```bash
gcloud config set project "$PROD_PROJECT_ID"
gcloud run services list --region "$PROD_REGION" --project "$PROD_PROJECT_ID"
PROD_URL="$(gcloud run services describe iris-mlops-api-prod --region "$PROD_REGION" --project "$PROD_PROJECT_ID" --format='value(status.url)')"
echo "$PROD_URL"
curl -X POST "${PROD_URL}/predict" \
  -H "Content-Type: application/json" \
  -d '{"sepal_length":6.1,"sepal_width":2.8,"petal_length":4.7,"petal_width":1.2}'
```

## 12) Quick troubleshooting commands

```bash
# List recent build failures
gcloud builds list --filter="status=FAILURE" --limit=10

# Describe latest build in current project
LATEST_BUILD="$(gcloud builds list --limit=1 --format='value(id)')"
gcloud builds describe "$LATEST_BUILD"

# Show Cloud Run revisions
gcloud run revisions list --region "$DEV_REGION" --project "$DEV_PROJECT_ID"
gcloud run revisions list --region "$PROD_REGION" --project "$PROD_PROJECT_ID"
```

## 13) Files used by this runbook

- `cloudbuild.yaml`
- `infra/terraform/modules/cloudbuild_trigger/trigger.tf`
- `infra/envs/dev/cloudbuild/terragrunt.hcl`
- `infra/envs/prod/cloudbuild/terragrunt.hcl`


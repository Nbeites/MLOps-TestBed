# MLOps TestBed (GCP): Terraform + Terragrunt + Cloud Build + Cloud Run

This repository is an end-to-end MLOps lab that combines:

- Infrastructure as code with Terraform and Terragrunt
- CI/CD with Cloud Build triggers and `cloudbuild.yaml`
- A dummy Python ML API (FastAPI) deployable to Cloud Run

It is designed so a new engineer with DevOps/MLOps basics can clone the repo and run the full flow.

## What Exists Today

- Application code: `app/main.py`, `train/train.py`, `Dockerfile`, `requirements.txt`
- Pipeline definition: `cloudbuild.yaml` (train model, build image, deploy to Cloud Run)
- Infra modules: `infra/terraform/modules/gcs_bucket`, `infra/terraform/modules/cloud_run_service`
- Dev environment wrapper: `infra/terragrunt/dev/terragrunt.hcl`

## CI/CD Trigger Layout (Implemented)

This repository now includes environment-separated trigger automation:

- Terraform Cloud Build trigger module: `infra/terraform/modules/cloudbuild_trigger/`
- Terragrunt environment folders:
  - `infra/envs/dev/cloudbuild/terragrunt.hcl`
  - `infra/envs/prod/cloudbuild/terragrunt.hcl`

Both envs call the same Terraform module with different inputs (`project_id`, `_ENV`, `branch_regex`, and similar substitutions).

## 1) Terragrunt + Terraform Architecture

Terraform and Terragrunt have different responsibilities:

- Terraform defines resources (Cloud Run service, bucket, trigger module)
- Terragrunt orchestrates per-environment deployment and input differences
- Terragrunt does not replace Terraform; it wraps it

### How the trigger pattern fits this repo

1. Use module `infra/terraform/modules/cloudbuild_trigger/` that creates `google_cloudbuild_trigger`.
2. Add one Terragrunt folder per environment:
   - `infra/envs/dev/cloudbuild/terragrunt.hcl`
   - `infra/envs/prod/cloudbuild/terragrunt.hcl`
3. Point both at the same module source, but pass different values:
   - DEV: `_ENV=dev`, `branch_regex=^develop$`, dev project id
   - PROD: `_ENV=prod`, `branch_regex=^main$`, prod project id

Running from each env folder:

```bash
terragrunt init
terragrunt apply
```

- In `dev`, it creates the DEV Cloud Build trigger
- In `prod`, it creates the PROD Cloud Build trigger

## 2) Cloud Build Trigger Behavior

A Cloud Build trigger is event-driven automation inside GCP.

- GitHub emits push/PR events
- Trigger checks branch/filter conditions
- If matched, Cloud Build starts automatically
- Cloud Build reads `cloudbuild.yaml` and executes the steps

Important boundary:

- Terraform only creates/manages the trigger resource
- Terraform never runs builds
- After creation, trigger execution is fully managed by GCP

Why it executes this pipeline file:

- Trigger resource sets `filename = "cloudbuild.yaml"`

## 3) `cloudbuild.yaml` Is the Full CI/CD Pipeline

`cloudbuild.yaml` defines more than image build. In this repo it is a full pipeline:

- Train and upload model artifact to GCS
- Build Docker image
- Push image
- Deploy to Cloud Run

Cloud Build executes steps in order on managed workers. The file is independent from Terraform/Terragrunt; IaC provisions infra, while the YAML defines runtime CI/CD behavior.

Every new matching GitHub event reruns this same pipeline automatically.

## 4) ML Playground Code (Dummy Python Project)

The application side is intentionally simple:

- FastAPI service in `app/main.py`
- Training entrypoint in `train/train.py`
- Containerization via `Dockerfile` and `requirements.txt`

The Cloud Build pipeline deploys this service to Cloud Run.

To adapt for real workloads, replace your app code and scripts (for example):

- `train.py`
- `predict.py`
- tests and validation scripts
- embedded/sample data for experimentation

Infra stays unchanged for normal code iterations; pushes trigger rebuild/redeploy automatically.

## 5) Dev vs Prod Workflow

Recommended branch-to-environment mapping:

- Push to `develop` -> DEV trigger -> deploy to DEV target
- Push to `main` -> PROD trigger -> deploy to PROD target

Both envs can use the same `cloudbuild.yaml` with substitutions:

- DEV trigger sets `_ENV=dev`
- PROD trigger sets `_ENV=prod`

This keeps one pipeline file while changing behavior through trigger-level inputs.

## 6) Cloud Shell Usage

Google Cloud Shell is suitable for this lab because it already includes the core tools (`gcloud`, Terraform, Terragrunt, Docker in supported flows).

You can:

- Clone repo and run infra commands without local setup
- Debug pipeline behavior manually:

```bash
gcloud builds submit --config cloudbuild.yaml .
```

- Inspect build/deploy state:

```bash
gcloud builds list
gcloud run services list
```

## 7) Quickstart for New Engineers

Use `QUICKSTART.md` for exact copy-paste steps:

- Authentication and project setup
- Create DEV trigger
- Create PROD trigger
- Push `develop` for DEV deployment
- Push `main` for PROD deployment
- Inspect logs and Cloud Run URLs

## 8) Final Outcome

With the documented trigger extension applied, this repository becomes a complete end-to-end MLOps CI/CD lab:

- Environment-separated trigger deployment via Terragrunt
- Automatic Cloud Build runs on GitHub pushes
- Single `cloudbuild.yaml` defining build + deploy behavior
- Python ML service deployable with no manual release steps
- Easy path to evolve into more advanced MLOps patterns

## Additional Documentation

- `QUICKSTART.md`: first-day setup and runbook
- `docs/CI_CD_ARCHITECTURE.md`: trigger behavior and env separation model
- `docs/LIFECYCLE.md`: lifecycle walkthrough
- `docs/IMPROVEMENTS.md`: advanced expansion ideas
- `docs/UV_AND_DOCKER_COMPOSE.md`: local developer workflow



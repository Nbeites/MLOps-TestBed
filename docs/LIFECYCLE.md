## End-to-End MLOps Lifecycle

This project is a small but realistic testbed for an end-to-end MLOps lifecycle on **Google Cloud**.
This document walks through the main phases and how they map to files, tools, and workflows in the repo.

---

### 1. Local Development

- **Goal**: Iterate quickly on training and serving code using local tools.
- **Key pieces**:
  - Training script: `train/train.py`
  - FastAPI service: `app/main.py`
  - Dependency manager: `uv` + `pyproject.toml`

**Typical flow (no cloud):**

```bash
# From repo root
uv run train/train.py
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
```

You can now hit `http://127.0.0.1:8080/predict` with `curl` or your favorite HTTP client.

---

### 2. Local Containers (Docker & Docker Compose)

- **Goal**: Run the API in a container similar to Cloud Run.
- **Key pieces**:
  - `Dockerfile` – defines the container for the FastAPI service.
  - `docker-compose.yml` – simple compose file to run the API locally.

**Typical flow:**

```bash
docker compose up --build

# In another terminal:
curl -X POST "http://127.0.0.1:8080/predict" \
  -H "Content-Type: application/json" \
  -d '{ "sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2 }'
```

You can optionally configure the container to pull the model from GCS by setting `MODEL_BUCKET` and `MODEL_BLOB` in `docker-compose.yml`.

---

### 3. Cloud Infrastructure (Terraform + Terragrunt)

- **Goal**: Manage core GCP resources as code so they are reproducible and easy to create/destroy.
- **Key pieces**:
  - Terraform modules:
    - `infra/terraform/modules/gcs_bucket` – creates a model bucket.
    - `infra/terraform/modules/cloud_run_service` – creates a Cloud Run service.
  - Environment configuration:
    - `infra/terraform/envs/dev/main.tf` – wires modules together for a `dev` environment.
  - Terragrunt:
    - `infra/terragrunt/dev/terragrunt.hcl` – points to the dev Terraform config and injects inputs.

**High-level flow (dev env example):**

1. Edit `infra/terragrunt/dev/terragrunt.hcl` and set:
   - `project_id`
   - `image` (e.g. `gcr.io/YOUR_DEV_PROJECT_ID/iris-mlops-api:latest` or a specific tag)
2. From `infra/terragrunt/dev`:

   ```bash
   terragrunt init
   terragrunt plan
   terragrunt apply
   ```

This will:

- Create a **GCS bucket** for models (e.g. `<project_id>-iris-mlops-demo-dev`).
- Create a **Cloud Run service** configured with:
  - `MODEL_BUCKET` pointing at the bucket.
  - `MODEL_BLOB` pointing at a path like `models/iris/latest/model.joblib`.

> Note: Terraform/Terragrunt do not build images or train models; they only manage infrastructure.

---

### 4. CI/CD with Cloud Build

- **Goal**: On every commit (or selected branch), automatically:
  1. Train a new model and upload it to a **versioned path** in GCS.
  2. Build and push a container image.
  3. Deploy the image to Cloud Run with the correct model version configured.

- **Key piece**:
  - `cloudbuild.yaml` in the repo root.

**What `cloudbuild.yaml` does:**

1. **Train and upload model**
   - Runs `uv run train/train.py` in a `python:3.13-slim` step.
   - Uses env vars:
     - `GCS_BUCKET=$_MODEL_BUCKET`
     - `GCS_MODEL_BLOB=models/iris/$_MODEL_VERSION/model.joblib`
   - `_MODEL_VERSION` defaults to `$SHORT_SHA` so each commit writes to a unique GCS path.

2. **Build and push image**
   - Builds a Docker image tagged as `$_IMAGE` (default: `gcr.io/$PROJECT_ID/iris-mlops-api:$SHORT_SHA`).
   - Pushes it to the container registry.

3. **Deploy to Cloud Run**
   - Deploys the new image to Cloud Run, setting:
     - `MODEL_BUCKET=$_MODEL_BUCKET`
     - `MODEL_BLOB=models/iris/$_MODEL_VERSION/model.joblib`
   - Uses Cloud Run flags for `--min-instances` and `--max-instances` (0 and 1 by default).

**Triggering the pipeline:**

- Create a **Cloud Build trigger** in the GCP console (or via CLI) that:
  - Watches your repository (e.g. GitHub, Cloud Source Repos).
  - Runs on push to `main` (or your branch).
  - Uses `cloudbuild.yaml` as the build config.

Once configured, each qualifying commit will produce:

- A new **model artifact** in GCS.
- A new **container image**.
- A new **Cloud Run revision** pointed at the new model version.

---

### 5. Serving and Model Versioning

The serving pattern is:

- `train/train.py` writes model to:

  ```text
  gs://<bucket>/models/iris/<version>/model.joblib
  ```

- Cloud Build deploys Cloud Run with:
  - `MODEL_BUCKET=<bucket>`
  - `MODEL_BLOB=models/iris/<version>/model.joblib`

On startup, `app/main.py`:

1. Checks if `MODEL_BUCKET` is set.
2. If so, downloads the model from GCS into `model.joblib` if not already present.
3. Loads the model and serves `/predict` and `/healthz`.

**Rollback / pinning a version:**

- To roll back, deploy a previous image and/or set `MODEL_BLOB` to an older path, for example:

```bash
gcloud run deploy iris-mlops-api \
  --image gcr.io/$PROJECT_ID/iris-mlops-api:OLD_SHA \
  --region europe-west1 \
  --allow-unauthenticated \
  --set-env-vars=MODEL_BUCKET=$BUCKET_NAME,MODEL_BLOB=models/iris/OLD_SHA/model.joblib
```

You can also use the Cloud Run UI to roll back to a previous revision.

---

### 6. Observability (Logging & Monitoring)

- **Logging**:
  - The FastAPI service writes to stdout/stderr, which Cloud Run sends to **Cloud Logging**.
  - You can extend `app/main.py` to emit structured logs (e.g. request features, predicted class).

- **Monitoring**:
  - Cloud Run exposes metrics like:
    - Request count
    - Latency percentiles
    - 4xx/5xx error rates
  - Use **Cloud Monitoring → Metrics Explorer** to:
    - Filter on your Cloud Run service.
    - Build dashboards.
    - Create alerting policies (e.g. high error rate).

Over time, you can extend this lifecycle with:

- Exporting logs to **BigQuery** for offline analysis.
- Adding a simple drift indicator based on predicted class distribution.
- Integrating experiment tracking tools (MLflow, Weights & Biases, etc.).

---

### 7. Putting It All Together

A typical full lifecycle for this testbed looks like:

1. **Develop locally**
   - Edit `train/train.py` and `app/main.py`.
   - Test via `uv run` and/or Docker Compose.
2. **Provision infra**
   - Use Terraform + Terragrunt (`infra/`) to create buckets and Cloud Run services.
3. **Set up CI/CD**
   - Add a Cloud Build trigger for `cloudbuild.yaml`.
4. **Commit and push**
   - Cloud Build trains, builds, and deploys.
5. **Monitor & iterate**
   - Check Cloud Run logs and metrics.
   - Adjust code, infra, and pipeline as needed.

This repo is intentionally small so you can experiment freely with each phase without a lot of cognitive overhead.


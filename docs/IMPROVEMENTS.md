## Making the Iris MLOps Demo More "MLOps-like"

This document shows **how to implement** the three improvements suggested in the main `README.md`:

- **1. Automated training + deployment pipeline (CI/CD)**
- **2. Model versioning and rollback**
- **3. Basic monitoring and logging**

Use these as incremental upgrades – you can adopt them one by one.

---

### 1. Automated Training + Deployment Pipeline

Goal: When you push to `main` (or a chosen branch), a pipeline should:

1. Train a new model.
2. Upload it to GCS (versioned path).
3. Build and push a container image.
4. Deploy the new image to Cloud Run.

Below is an example using **Cloud Build**.

#### 1.1. Create a dedicated GCS path for versioned models

Decide on a convention, for example:

```text
gs://YOUR_BUCKET/models/iris/${SHORT_SHA}/model.joblib
```

This uses the Git commit short SHA as a version identifier.

#### 1.2. Parameterize `train/train.py` for dynamic blob names (optional)

You can already control the blob name via `GCS_MODEL_BLOB`. For CI, you might set:

```bash
GCS_MODEL_BLOB=models/iris/${SHORT_SHA}/model.joblib
```

No code changes are strictly required if you only use env vars.

#### 1.3. Add a `cloudbuild.yaml`

Create `cloudbuild.yaml` in the project root:

```yaml
steps:
  # 1) Train model and upload to GCS
  - name: python:3.13-slim
    id: "train-model"
    entrypoint: bash
    args:
      - -c
      - |
        pip install uv
        uv run train/train.py

    env:
      - GCS_BUCKET=$_MODEL_BUCKET
      - GCS_MODEL_BLOB=models/iris/$_MODEL_VERSION/model.joblib

  # 2) Build and push container image
  - name: gcr.io/cloud-builders/docker
    id: "build-and-push-image"
    args:
      - build
      - "-t"
      - "$_IMAGE"
      - "."

  - name: gcr.io/cloud-builders/docker
    id: "push-image"
    args:
      - push
      - "$_IMAGE"

  # 3) Deploy to Cloud Run
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    id: "deploy-cloud-run"
    entrypoint: bash
    args:
      - -c
      - |
        gcloud run deploy $_SERVICE_NAME \
          --image=$_IMAGE \
          --region=$_REGION \
          --allow-unauthenticated \
          --min-instances=0 \
          --max-instances=1 \
          --set-env-vars=MODEL_BUCKET=$_MODEL_BUCKET,MODEL_BLOB=models/iris/$_MODEL_VERSION/model.joblib

substitutions:
  # Provide defaults; override in trigger or CLI
  _REGION: "europe-west1"
  _SERVICE_NAME: "iris-mlops-api"
  _IMAGE: "gcr.io/$PROJECT_ID/iris-mlops-api:$SHORT_SHA"
  _MODEL_BUCKET: "$PROJECT_ID-iris-mlops-demo"
  _MODEL_VERSION: "$SHORT_SHA"

images:
  - "$_IMAGE"
```

This pipeline:

- Trains the model (using `uv`) and uploads it with a commit-based version.
- Builds and pushes a Docker image tagged with the commit SHA.
- Deploys to Cloud Run pointing to the correct model version.

#### 1.4. Create a Cloud Build trigger

In the GCP Console (or via CLI):

- **Source**: your Git repository (GitHub/Cloud Source Repos).
- **Trigger type**: push to branch (e.g. `main`).
- **Build config**: `cloudbuild.yaml` in repository.

Now each push to `main` will run the training + deploy pipeline.

---

### 2. Model Versioning and Rollback

Goal: Be able to:

- Deploy specific **model versions**.
- **Rollback** to a previous version quickly.

#### 2.1. Versioned paths in GCS

Store models with explicit versions, e.g.:

```text
gs://YOUR_BUCKET/models/iris/v1/model.joblib
gs://YOUR_BUCKET/models/iris/v2/model.joblib
...
```

or using dates/commits:

```text
gs://YOUR_BUCKET/models/iris/2026-03-09_120000/model.joblib
gs://YOUR_BUCKET/models/iris/commit-<SHORT_SHA>/model.joblib
```

You control this entirely via the `GCS_MODEL_BLOB` / `MODEL_BLOB` env vars.

#### 2.2. Deploying a specific version

When you deploy to Cloud Run, set `MODEL_BLOB` to that version:

```bash
gcloud run deploy iris-mlops-api \
  --image gcr.io/$PROJECT_ID/iris-mlops-api:v2 \
  --region europe-west1 \
  --allow-unauthenticated \
  --set-env-vars=MODEL_BUCKET=${BUCKET_NAME},MODEL_BLOB=models/iris/v2/model.joblib
```

This tells the service exactly which model version to load on startup.

#### 2.3. Rolling back

To roll back, just redeploy with a previous version path:

```bash
gcloud run deploy iris-mlops-api \
  --image gcr.io/$PROJECT_ID/iris-mlops-api:v1 \
  --region europe-west1 \
  --allow-unauthenticated \
  --set-env-vars=MODEL_BUCKET=${BUCKET_NAME},MODEL_BLOB=models/iris/v1/model.joblib
```

You can also use the Cloud Run UI to:

- Select a previous **revision**.
- Click **Rollback**.

As long as each revision has the correct `MODEL_BLOB`, you can move between versions safely.

---

### 3. Basic Monitoring and Logging

Goal: Get visibility into:

- Request volume and latency.
- Errors.
- High-level model behavior.

Cloud Run integrates with **Cloud Logging** and **Cloud Monitoring** automatically.

#### 3.1. Logging request + prediction info

In `app/main.py`, you already return predictions. You can enhance logging by printing summary info (which becomes Cloud Logs).

Example sketch (inside `predict` endpoint):

```python
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

@app.post("/predict", response_model=IrisPrediction)
def predict(iris: IrisRequest) -> IrisPrediction:
    ...
    result = IrisPrediction(
        predicted_class=predicted_class,
        class_index=class_idx,
        class_probabilities=[float(p) for p in proba],
    )

    logger.info(
        "prediction",
        extra={
            "time": datetime.utcnow().isoformat(),
            "features": {
                "sepal_length": iris.sepal_length,
                "sepal_width": iris.sepal_width,
                "petal_length": iris.petal_length,
                "petal_width": iris.petal_width,
            },
            "predicted_class": predicted_class,
            "class_index": class_idx,
        },
    )

    return result
```

These logs show up in **Cloud Logging** under:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="iris-mlops-api"
```

You can later:

- Export logs to **BigQuery** for analysis.
- Build dashboards from them.

#### 3.2. Monitoring latency and error rates

Cloud Run automatically exposes metrics such as:

- `request_count`
- `request_latencies`
- `error_count (5xx)`

In the GCP Console:

1. Go to **Monitoring → Metrics Explorer**.
2. Select:
   - **Resource type**: `Cloud Run Revision`.
   - **Metric**: e.g. `Request count`, `Request latency`, or `Error count`.
3. Filter by your service name.

You can then:

- Create a **dashboard** with:
  - Request volume.
  - 95th percentile latency.
  - 5xx error rate.
- Add **alerting policies**, e.g.:
  - Alert when 5xx error rate exceeds 5% for 5 minutes.
  - Alert when latency is above 1s for 10 minutes.

#### 3.3. Simple drift indicator (optional)

Without labels, you can still get a crude indication of drift by monitoring the **distribution of predicted classes** over time.

Example approach:

- Periodically run a small job (Cloud Run Job / Cloud Functions / Cloud Scheduler + Cloud Run) that:
  - Reads recent prediction logs from Cloud Logging or BigQuery.
  - Aggregates class counts per time window.
  - Stores metrics or flags anomalies.

This is **beyond the minimal demo**, but the current logging setup is enough to enable it later.

---

### 4. Suggested Implementation Order

1. **Start with CI/CD (Cloud Build)**:
   - Automates training + deploy on each commit.
2. **Add model versioning**:
   - Store models under versioned paths and deploy specific versions.
3. **Enable monitoring and logging**:
   - Make sure you can see what the model is doing in production.

Each step builds on the existing minimal project while keeping GCP cost and complexity low.


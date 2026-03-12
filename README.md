## Iris MLOps Demo on Google Cloud (Cloud Run + GCS)

Minimal end-to-end MLOps-style project using:

- **Python + scikit-learn** for training
- **FastAPI** for serving predictions
- **Docker** for containerization
- **Google Cloud Storage (GCS)** for model storage
- **Cloud Run** for serverless deployment (scale-to-zero, near \$0 cost)
- **gcloud CLI** for deployment (Cloud Build is used implicitly by `gcloud run deploy --source` if you choose that option)

The whole project is designed to be **simple**, **cheap**, and **deployable in under 1 hour** by someone with DevOps experience and basic Python knowledge.

---

### 1. Project Structure

```text
MLOps-Demo/
├─ app/
│  └─ main.py           # FastAPI app that loads the model and serves predictions
├─ train/
│  └─ train.py          # Script to train Iris model and upload to GCS
├─ docs/
│  ├─ QUICKSTART.md     # Very short "how to run" guide
│  ├─ UV_AND_DOCKER_COMPOSE.md  # Details on uv + docker compose
│  └─ IMPROVEMENTS.md   # How to implement the advanced MLOps improvements
├─ pyproject.toml       # Python dependencies (managed by uv)
├─ requirements.txt     # Exported deps for Docker / tools
├─ Dockerfile           # Container image for Cloud Run / local tests
├─ .gitignore           # Ignore model artifacts, venvs, IDE, OS files (keep updated)
└─ README.md            # Main project overview and full instructions
```

Optional (not included, but easy to add later):

- `cloudbuild.yaml` for explicit CI build pipeline.

---

### 2. Architecture Overview

**High-level flow:**

```text
            (local dev)
          +------------------+
          | train/train.py   |
          |  - loads Iris    |
          |  - trains model  |
          |  - saves model   |
          |  - uploads to    |
          |    GCS bucket    |
          +--------+---------+
                   |
                   | model.joblib
                   v
          +-----------------------+
          |  GCS Bucket           |
          |  (e.g. iris-mlops-bkt)|
          +-----------+-----------+
                      |
                      | download at startup
                      v
        +---------------------------+
        | Cloud Run Service         |
        |  FastAPI /predict         |
        |  - pulls model from GCS   |
        |  - serves HTTP JSON API   |
        +---------------------------+
                      ^
                      |
         curl / HTTP clients (CLI, Postman, apps)
```

**Key GCP resources:**

- **1× GCS bucket** for the trained model artifact.
- **1× Cloud Run service** for the API (min instances = 0 for near-zero idle cost).
- **(Optional)** Cloud Build triggers if you later add CI.

---

### 3. Prerequisites

- **Google Cloud account** with billing enabled.
- **gcloud CLI** installed and authenticated.
- **Docker** installed (for local container tests, optional).
- **uv (Python dependency manager)** installed (recommended for local runs).

#### 3.1. Install uv (once)

See the official docs: [`https://docs.astral.sh/uv/getting-started/`](https://docs.astral.sh/uv/getting-started/).

On most systems you can run:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

If you ever change dependencies in `pyproject.toml` and want to **regenerate `requirements.txt`** (for Docker or other tools), run:

```bash
uv export --format requirements.txt --output-file requirements.txt
```

#### 3.2. Configure gcloud

From a terminal:

```bash
gcloud auth login
gcloud auth application-default login   # for local GCS access using ADC (optional)
gcloud config set project YOUR_PROJECT_ID
```

Replace `YOUR_PROJECT_ID` with your actual GCP project ID.

---

### 4. Local Quickstart (Minimal Commands)

If you just want the **short runbook**, open `docs/QUICKSTART.md`.

This is the **shortest path** to get everything running **locally only** (no GCS, no Cloud Run).

From the project root (`MLOps-Demo`):

```bash
# 1) Train the model (creates model.joblib locally)
uv run train/train.py

# 2) Start the API
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Then in another terminal:

```bash
curl -X POST "http://127.0.0.1:8080/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "sepal_length": 5.1,
    "sepal_width": 3.5,
    "petal_length": 1.4,
    "petal_width": 0.2
  }'
```

This uses:

- **uv** + `pyproject.toml` to automatically create an isolated environment and install dependencies.
- A local `model.joblib` file (no GCS needed for local tests).

---

### 5. Setup and Local Training with GCS (for Cloud Run)

If you want to use **Cloud Run** with the model stored in **GCS**, follow these steps.

#### 5.1. Create a GCS bucket for the model

Pick a globally-unique bucket name, for example:

```bash
export PROJECT_ID=your-project-id
export REGION=europe-west1   # or any region you prefer
export BUCKET_NAME=${PROJECT_ID}-iris-mlops-demo

gcloud storage buckets create gs://${BUCKET_NAME} --location=${REGION}
```

#### 5.2. Train the model and upload it to GCS

Run the training script from the project root with env vars set:

```bash
export GCS_BUCKET=${BUCKET_NAME}
export GCS_MODEL_BLOB=models/iris/model.joblib  # default used by the app

uv run train/train.py
```

What this does:

- Loads the **Iris dataset** from scikit-learn.
- Trains a **RandomForestClassifier**.
- Saves the model as `model.joblib` in the project root.
- Uploads the model to `gs://${GCS_BUCKET}/${GCS_MODEL_BLOB}`.

---

### 6. Local API Run with GCS (Optional)

If you want to **simulate Cloud Run behavior locally** (API loading from GCS instead of a local file), you can:

1. Make sure the model is uploaded to GCS (previous step).
2. Set `MODEL_BUCKET` and `MODEL_BLOB` so the API downloads from GCS on startup.

From the project root:

```bash
export MODEL_BUCKET=${BUCKET_NAME}
export MODEL_BLOB=models/iris/model.joblib

uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Then test with the same **curl** command as in the local quickstart.

---

### 7. Containerization with Docker

The `Dockerfile` builds a minimal image and runs the FastAPI app via `uvicorn`:

- Base image: `python:3.11-slim`
- Installs dependencies from `requirements.txt`
- Copies the project code
- Runs `uvicorn app.main:app` on port `8080`

#### 7.1. Build the Docker image locally (optional)

```bash
export PROJECT_ID=your-project-id
docker build -t iris-mlops-api:latest .
```

#### 7.2. Run the container locally

```bash
docker run --rm -p 8080:8080 iris-mlops-api:latest
```

Then use the same **curl** command as in the local section.

---

### 8. Deploying to Cloud Run (with gcloud CLI)

You have two options:

1. **Use `gcloud run deploy --source .`** (simpler; uses Cloud Build automatically).
2. **Build the container yourself and deploy the image** (more explicit, classic Docker flow).

#### Option A: Deploy from source (simplest)

From the project root:

```bash
export PROJECT_ID=your-project-id
export REGION=europe-west1
export SERVICE_NAME=iris-mlops-api

gcloud run deploy ${SERVICE_NAME} \
  --source . \
  --region ${REGION} \
  --project ${PROJECT_ID} \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=1 \
  --set-env-vars=MODEL_BUCKET=${BUCKET_NAME},MODEL_BLOB=models/iris/model.joblib
```

What this does:

- Uses **Cloud Build** under the hood to build the container.
- Deploys to **Cloud Run** in the specified region.
- Configures environment variables so the service knows which GCS bucket/blob to pull the model from.
- Sets **min instances to 0** and **max to 1** to keep costs near zero.

The command will output a **service URL**, e.g.:

```text
https://iris-mlops-api-xyz-uc.a.run.app
```

#### Option B: Build image + deploy explicit image

1. **Build and push image (Artifact Registry or GCR)**:

   ```bash
   export PROJECT_ID=your-project-id
   export REGION=europe-west1
   export SERVICE_NAME=iris-mlops-api
   export IMAGE=gcr.io/${PROJECT_ID}/${SERVICE_NAME}:v1

   gcloud builds submit --tag ${IMAGE} .
   ```

2. **Deploy to Cloud Run**:

   ```bash
   gcloud run deploy ${SERVICE_NAME} \
     --image ${IMAGE} \
     --region ${REGION} \
     --project ${PROJECT_ID} \
     --allow-unauthenticated \
     --min-instances=0 \
     --max-instances=1 \
     --set-env-vars=MODEL_BUCKET=${BUCKET_NAME},MODEL_BLOB=models/iris/model.joblib
   ```

---

### 9. Example curl Request (Cloud Run)

Once deployed, use the **Cloud Run service URL**:

```bash
export SERVICE_URL="https://iris-mlops-api-xyz-uc.a.run.app"  # replace with your URL

curl -X POST "${SERVICE_URL}/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "sepal_length": 6.1,
    "sepal_width": 2.8,
    "petal_length": 4.7,
    "petal_width": 1.2
  }'
```

You should receive a JSON prediction similar to the local example.

Health check:

```bash
curl "${SERVICE_URL}/healthz"
```

---

### 10. GCP Resources Required

- **Cloud Storage bucket**
  - Stores `model.joblib` under `models/iris/model.joblib`.
  - Used by both the local training script (upload) and the Cloud Run service (download).

- **Cloud Run service**
  - Runs the FastAPI app.
  - Scales from 0 to 1 instance (as configured).
  - Exposes `/predict` and `/healthz` endpoints.

- **(Implicit) Cloud Build**
  - Invoked automatically by `gcloud run deploy --source .`, or manually if you use `gcloud builds submit`.

No other resources (e.g. databases, Pub/Sub, etc.) are required for this minimal demo.

---

### 11. Cost Estimates

This project is designed to cost **almost nothing**:

- **Cloud Run**
  - With **min instances = 0**, you pay only for actual request time.
  - Light demo traffic will be well within the **free tier** for most accounts.

- **Cloud Storage**
  - Storing a single small `model.joblib` file (a few KB/MB) costs fractions of a cent per month.

- **Cloud Build**
  - Occasional small builds are typically covered by free tier as well.

With a single small model, occasional manual runs, and near-zero idle time, **real-world monthly cost is typically \$0–\$1**.

---

### 12. How This Demonstrates Basic MLOps Concepts

- **Reproducible training**: `train/train.py` trains the model in a deterministic way (fixed random seed).
- **Artifact storage**: Model file is stored in **GCS** as a versionable, shareable artifact.
- **Decoupled training and serving**:
  - Training happens locally or in CI via `train.py`.
  - Serving happens in **Cloud Run** using the artifact from GCS.
- **Containerization**: Dockerfile defines a consistent runtime for the API.
- **CLI-based workflow**: All key operations (training, building, deploying, testing) can be run from the **command line**.

---

### 13. Making It More "MLOps-like": Next Steps

To evolve this minimal demo into a more complete MLOps setup (pipelines, versioning, monitoring), see `docs/IMPROVEMENTS.md`.



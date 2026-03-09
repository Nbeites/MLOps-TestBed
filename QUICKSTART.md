## Quickstart: Run the Iris MLOps Demo

This is the **short, practical guide**. For full details, see `README.md`.

All commands are run from the project root: `MLOps-TestBed`.

---

### 1. Prerequisites

- `uv` installed (Python dependency manager).
- `curl` installed.
- (Optional) `docker` & `docker compose` if you want to use containers.
- (Optional) `gcloud` if you want to deploy to Cloud Run.

---

### 2. Local Run (no Docker, no GCS)

```bash
# 1) Train the model (creates model.joblib locally)
uv run train/train.py

# 2) Start the API
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
```

In another terminal:

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

---

### 3. Docker: Train and run the API

**Step 1 — Train the model** (writes `model.joblib` to the project directory):

```bash
docker compose run --rm train
```

**Step 2 — Run the API** (uses the model from the project directory):

```bash
docker compose up api
```

Or run the API in the foreground once and exit:

```bash
docker compose run --rm -p 8080:8080 api
```

Then in another terminal:

```bash
curl -X POST "http://127.0.0.1:8080/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "sepal_length": 6.1,
    "sepal_width": 2.8,
    "petal_length": 4.7,
    "petal_width": 1.2
  }'
```

Stop the API (if you used `docker compose up api`):

```bash
docker compose down
```

---

### 4. Deploy to Cloud Run (minimal flow)

High-level steps (details in `README.md`):

1. Create a bucket and train/upload model:

   ```bash
   export PROJECT_ID=your-project-id
   export REGION=europe-west1
   export BUCKET_NAME=${PROJECT_ID}-iris-mlops-demo

   gcloud storage buckets create gs://${BUCKET_NAME} --location=${REGION}

   export GCS_BUCKET=${BUCKET_NAME}
   export GCS_MODEL_BLOB=models/iris/model.joblib

   uv run train/train.py
   ```

2. Deploy from source to Cloud Run:

   ```bash
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

3. Test the Cloud Run endpoint (replace URL with your service URL):

   ```bash
   export SERVICE_URL="https://iris-mlops-api-xyz-uc.a.run.app"

   curl -X POST "${SERVICE_URL}/predict" \
     -H "Content-Type: application/json" \
     -d '{
       "sepal_length": 6.1,
       "sepal_width": 2.8,
       "petal_length": 4.7,
       "petal_width": 1.2
     }'
   ```


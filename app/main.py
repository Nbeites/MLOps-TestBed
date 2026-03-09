import os
from pathlib import Path
from typing import List

import joblib
from fastapi import FastAPI, HTTPException
from google.cloud import storage
from pydantic import BaseModel, Field


BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_LOCAL_PATH = BASE_DIR / "model.joblib"


class IrisRequest(BaseModel):
    sepal_length: float = Field(..., example=5.1)
    sepal_width: float = Field(..., example=3.5)
    petal_length: float = Field(..., example=1.4)
    petal_width: float = Field(..., example=0.2)


class IrisPrediction(BaseModel):
    predicted_class: str
    class_index: int
    class_probabilities: List[float]


app = FastAPI(title="Iris ML MLOps Demo", version="0.1.0")

model = None
target_names: List[str] = []


def download_from_gcs_if_needed() -> None:
    """Download model from GCS if MODEL_BUCKET is set."""
    bucket_name = os.getenv("MODEL_BUCKET")
    blob_name = os.getenv("MODEL_BLOB", "models/iris/model.joblib")

    if not bucket_name:
        # No bucket configured; assume model is already present locally (e.g. baked into image)
        return

    if MODEL_LOCAL_PATH.exists():
        # Already downloaded / present
        return

    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)

    MODEL_LOCAL_PATH.parent.mkdir(parents=True, exist_ok=True)
    blob.download_to_filename(str(MODEL_LOCAL_PATH))
    print(f"Downloaded model from gs://{bucket_name}/{blob_name} to {MODEL_LOCAL_PATH}")


def load_model() -> None:
    global model, target_names

    download_from_gcs_if_needed()

    if not MODEL_LOCAL_PATH.exists():
        raise RuntimeError(
            f"Model file not found at {MODEL_LOCAL_PATH}. "
            "Run the training script first or configure MODEL_BUCKET/MODEL_BLOB."
        )

    payload = joblib.load(MODEL_LOCAL_PATH)
    model = payload["model"]
    target_names = list(payload["target_names"])
    print("Model loaded successfully.")


@app.on_event("startup")
def on_startup() -> None:
    load_model()


@app.get("/healthz")
def healthcheck() -> dict:
    return {"status": "ok"}


@app.post("/predict", response_model=IrisPrediction)
def predict(iris: IrisRequest) -> IrisPrediction:
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")

    features = [
        [
            iris.sepal_length,
            iris.sepal_width,
            iris.petal_length,
            iris.petal_width,
        ]
    ]

    try:
        import numpy as np

        proba = model.predict_proba(features)[0]
        class_idx = int(np.argmax(proba))
    except Exception:
        # Fallback if model does not support predict_proba
        class_idx = int(model.predict(features)[0])
        proba = []

    predicted_class = target_names[class_idx] if target_names else str(class_idx)

    return IrisPrediction(
        predicted_class=predicted_class,
        class_index=class_idx,
        class_probabilities=[float(p) for p in proba],
    )


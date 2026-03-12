import os
from pathlib import Path

import joblib
from google.cloud import storage
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split


BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_LOCAL_PATH = BASE_DIR / "model.joblib"


def upload_to_gcs(bucket_name: str, local_path: Path, blob_name: str) -> None:
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    blob.upload_from_filename(str(local_path))
    print(f"Uploaded model to gs://{bucket_name}/{blob_name}")


def main() -> None:
    print("Loading Iris dataset...")
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )

    print("Training RandomForestClassifier...")
    clf = RandomForestClassifier(random_state=42)
    clf.fit(X_train, y_train)

    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"Test accuracy: {acc:.3f}")

    print(f"Saving model to {MODEL_LOCAL_PATH} ...")
    joblib.dump(
        {
            "model": clf,
            "target_names": iris.target_names,
            "feature_names": iris.feature_names,
        },
        MODEL_LOCAL_PATH,
    )

    bucket_name = os.getenv("GCS_BUCKET")
    blob_name = os.getenv("GCS_MODEL_BLOB", "models/iris/model.joblib")

    if bucket_name:
        print(f"Uploading model to GCS bucket '{bucket_name}' as '{blob_name}' ...")
        upload_to_gcs(bucket_name=bucket_name, local_path=MODEL_LOCAL_PATH, blob_name=blob_name)
    else:
        print("GCS_BUCKET not set. Skipping upload to Google Cloud Storage.")

    print("Training finished.")


if __name__ == "__main__":
    main()


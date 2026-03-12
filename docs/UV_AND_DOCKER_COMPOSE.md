## Using uv and Docker Compose in This Project

This guide shows you how to:

- **Use `uv`** as the Python dependency manager for this project.
- **Run the API in Docker Compose** for local testing.

Everything assumes you are in the project root: `MLOps-Demo`.

---

### 1. Using `uv` for Python Dependencies

The project uses `pyproject.toml` to declare dependencies, and **uv** to manage them.

#### 1.1. Install uv (once on your machine)

Official docs: [`https://docs.astral.sh/uv/getting-started/`](https://docs.astral.sh/uv/getting-started/).

Typical install (on Linux/macOS):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

On Windows, see the docs for the recommended installer or use:

```powershell
irm https://astral.sh/uv/install.ps1 | iex
```

After installation, ensure `uv` is on your `PATH`:

```bash
uv --version
```

#### 1.2. How environments work with uv

- You **do not** create virtualenvs manually.
- `uv run` and `uv pip` automatically:
  - Create a project-specific environment (based on `pyproject.toml`).
  - Install the required dependencies into that environment.

You don’t need to `pip install` anything manually for this project.

#### 1.3. Common uv commands for this project

From the project root (`MLOps-Demo`):

- **Train the model locally (no GCS):**

  ```bash
  uv run train/train.py
  ```

- **Train and upload to GCS:**

  ```bash
  export GCS_BUCKET=${BUCKET_NAME}
  export GCS_MODEL_BLOB=models/iris/model.joblib

  uv run train/train.py
  ```

- **Run the FastAPI app (local model file):**

  ```bash
  uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
  ```

- **Run the FastAPI app (download model from GCS):**

  ```bash
  export MODEL_BUCKET=${BUCKET_NAME}
  export MODEL_BLOB=models/iris/model.joblib

  uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
  ```

uv will install/update dependencies only when needed and reuse the same environment for subsequent runs.

---

### 2. Running the API with Docker Compose

You can run the API service in a local container using **Docker Compose**. This is useful to:

- Mirror how the service will run on Cloud Run.
- Have a repeatable way to spin up the container locally.

#### 2.1. `docker-compose.yml`

The project includes a `docker-compose.yml` (see root of the repo) with a single service:

- Builds the image from the local `Dockerfile`.
- Exposes port **8080** on your machine.
- Optionally passes model-related env vars (if you want it to load from GCS).

`docker-compose.yml` looks like this:

```yaml
version: "3.9"

services:
  api:
    build: .
    container_name: iris-mlops-api
    ports:
      - "8080:8080"
    environment:
      # Uncomment and set these if you want the container
      # to download the model from GCS on startup.
      # MODEL_BUCKET: "your-bucket-name"
      # MODEL_BLOB: "models/iris/model.joblib"
    # If you want to use a local model.joblib baked into the image,
    # just make sure you ran the training script before building.
```

#### 2.2. Build and run with Docker Compose

From the project root:

```bash
docker compose up --build
```

This will:

- Build the image using the `Dockerfile`.
- Start the `api` service, mapping container port 8080 to `localhost:8080`.

To stop:

```bash
docker compose down
```

#### 2.3. Test the API via Docker Compose

Once `docker compose up --build` is running, in another terminal:

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

You should see a JSON response with the predicted Iris class and probabilities.

#### 2.4. Using GCS with Docker Compose (optional)

If you want the container to fetch the model from **GCS** on startup:

1. Make sure the model is already uploaded (e.g. via `uv run train/train.py` with `GCS_BUCKET` / `GCS_MODEL_BLOB`).
2. Edit `docker-compose.yml` and set:

   ```yaml
   environment:
     MODEL_BUCKET: "your-bucket-name"
     MODEL_BLOB: "models/iris/model.joblib"
   ```

3. Rebuild and run:

   ```bash
   docker compose up --build
   ```

The container will:

- Use the GCP credentials available in your environment (for local dev, typically via `gcloud auth application-default login`).
- Download the model from GCS into the container at startup.

---

### 3. Quick Reference

- **Local runs with uv (no Docker):**

  ```bash
  uv run train/train.py
  uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
  ```

- **Local container with Docker Compose (Dockerized API):**

  ```bash
  docker compose up --build
  # in another terminal
  curl -X POST "http://127.0.0.1:8080/predict" ...
  ```

This keeps your workflow simple while still being close to how the service runs on Cloud Run.


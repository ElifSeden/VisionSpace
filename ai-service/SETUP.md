# Setup Guide — VisionSpace AI Service

## Prerequisites

- **Docker** and **Docker Compose** (v2+)
- A **Google Cloud** project with the following APIs enabled:
  - Vertex AI API
  - Vertex AI Multimodal API (for image embeddings)
- A **GCP service account** with the `roles/aiplatform.user` role

---

## Step 1 — Clone and Configure

```bash
cd ai-service
cp .env.example .env
```

Edit `.env` and set your values:

```env
VERTEX_PROJECT_ID=your-gcp-project-id   # required
VERTEX_MODEL_ID=gemini-3-flash-preview   # light tasks
VERTEX_PRO_MODEL_ID=gemini-3.1-pro-preview  # heavy reasoning
VERTEX_MULTIMODAL_LOCATION=us-central1   # region for image embeddings
PRODUCT_EMBEDDING_IMAGE_ROOT=/data/pipeline/output/images  # local product image root
```

Change `POSTGRES_PASSWORD` if deploying to a server.

---

## Step 2 — Add GCP Credentials

Place your service account key in the `secrets/` directory:

```bash
mkdir -p secrets
cp /path/to/your-service-account-key.json secrets/gcp-service-account.json
```

The Docker containers mount this file read-only at `/secrets/gcp-service-account.json`.

> **Security**: The `secrets/` directory is in `.gitignore`. Never commit credentials.

---

## Step 3 — Start Services

```bash
make setup
```

This single command:
1. Builds and starts all containers (API, migration job, worker, PostgreSQL, Redis, Qdrant, Adminer)
2. Runs database migrations (Alembic) through the Compose `migrate` service before API/worker startup
3. Creates the Qdrant vector collection with **dual named vectors**:
   - `text` (768-dim) for semantic text search
   - `image` (1408-dim) for visual similarity search

If an existing server database is reachable but tables such as `design_jobs` are missing, run the migration job once:

```bash
docker compose run --rm migrate
```

---

## Step 4 — Import Product Data

If you have enriched product data from the preprocessor:

```bash
make import-enriched
```

This imports `enriched_products.jsonl` from the data pipeline directory. To specify a custom file:

```bash
make import-enriched file=/path/to/your/enriched_products.jsonl
```

> **Note**: The path must be accessible inside the Docker container. The default mount maps `../data/` to `/data/pipeline/` inside the container.

---

## Step 5 — Index Products (Text + Image Vectors)

```bash
make index-products
```

This step:
1. Embeds all products' **semantic text** using `text-embedding-005` (768-dim vectors)
2. Reads each product's **primary image** from the local crawler image path under `PRODUCT_EMBEDDING_IMAGE_ROOT`
3. Uploads the image bytes directly to `multimodalembedding@001` (1408-dim vectors)
4. Upserts both vectors as named vectors into Qdrant

> **Note**: The default Compose mount maps `../data/output/images` to `/data/pipeline/output/images`. Products without readable local images get a fallback vector.

---

## Step 6 — Verify

Check the API is running:

```bash
curl http://localhost:8000/health
# {"status":"ok"}
```

Open the interactive API docs:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Adminer** (DB): http://localhost:8080

---

## Usage — Full Design Flow

### 1. Upload a room image

```bash
curl -X POST http://localhost:8000/uploads/room-image \
  -F "file=@/path/to/room.jpg"
```

Response:
```json
{"image_path": "rooms/2026/05/abc123.jpg", "width": 1920, "height": 1080}
```

### 2. Create a design job

```bash
curl -X POST http://localhost:8000/design-jobs \
  -H "Content-Type: application/json" \
  -d '{
    "room_image_path": "rooms/2026/05/abc123.jpg",
    "room_dimensions": {"unit": "cm", "current_wall_length_cm": 400},
    "preferences": {"design_style": "modern", "temperature": "warm"},
    "requested_design_count": 2
  }'
```

Response:
```json
{"job_id": "550e8400-...", "status": "queued"}
```

### 3. Poll for results

```bash
curl http://localhost:8000/design-jobs/550e8400-...
```

The job progresses through: `queued` → `running` → `completed` (or `failed`).

When completed, the response contains full design proposals with product selections and placement polygons. Product retrieval uses **hybrid search** — the uploaded room image is compared against product images for visual style matching.

---

## How Hybrid Search Works

When the AI pipeline searches for furniture to recommend:

1. **Text search**: The query (e.g., "modern warm dining table") is embedded and matched against product descriptions
2. **Image search**: Your uploaded room photo is embedded and matched against product images — finding furniture that *looks like it belongs* in your room
3. **Score fusion**: Text (60%) + Image (40%) similarity are combined with attribute matching for final ranking

This means products are selected not just by keyword matching, but by **visual style compatibility** with your actual room.

---

## Makefile Reference

| Command | Description |
|---|---|
| `make setup` | Build, start, migrate, create Qdrant collection |
| `make up` | Build and start all containers |
| `make down` | Stop all containers |
| `make logs` | Follow container logs |
| `make migrate` | Run Alembic migrations |
| `make import-enriched` | Import enriched product data |
| `make index-products` | Vectorize products into Qdrant (text + images) |
| `make create-qdrant` | Create/recreate Qdrant collection |

---

## Moving to a Server

The system is fully portable via Docker:

1. Copy the `ai-service/` directory to the server
2. Copy your `.env` file (update `POSTGRES_PASSWORD` for production)
3. Copy your `secrets/gcp-service-account.json`
4. Copy your enriched product data to the expected location
5. Run `make setup && make import-enriched && make index-products`

All service URLs (PostgreSQL, Redis, Qdrant) resolve via Docker's internal networking — no host changes needed.

For production, consider:
- Placing a reverse proxy (Nginx/Caddy) in front of port 8000
- Using Docker volumes or bind mounts for persistent data
- Setting `APP_ENV=production` and disabling `--reload` in the API command

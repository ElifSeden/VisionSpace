# SYSTEM.md — VisionSpace AI Service Architecture

> This document describes the complete architecture of the `ai-service`. An AI agent or developer should be able to read this file and fully understand every component, its responsibilities, and how they connect.

---

## 1. Overview

The AI Service is a **furniture recommendation backend**. A client uploads a room photograph, and the service:

1. Analyzes the room (type, style, existing furniture, available zones)
2. Creates design strategies (creative furniture concepts)
3. Retrieves matching products from a vector database using **hybrid text + image search**
4. Ranks and selects the best products
5. Plans spatial placements (where each product goes in the room)
6. Persists the final design and returns it via API

The entire pipeline is orchestrated by a **LangGraph state machine**. Heavy reasoning uses **Vertex AI (gemini-3.1-pro-preview)**; lightweight tasks use **gemini-3-flash-preview**. Product search uses a **dual-vector architecture**: text embeddings from `text-embedding-005` and image embeddings from `multimodalembedding@001`, stored as named vectors in **Qdrant**.

---

## 2. Technology Stack

| Layer | Technology |
|---|---|
| API framework | FastAPI (Python 3.12) |
| Task queue | RQ (Redis Queue) |
| Workflow engine | LangGraph |
| Relational DB | PostgreSQL 16 |
| Vector DB | Qdrant (dual named vectors) |
| Cache / queue broker | Redis 7 |
| AI provider | Google Cloud Vertex AI |
| Text embeddings | `text-embedding-005` (768-dim) |
| Image embeddings | `multimodalembedding@001` (1408-dim) |
| Authentication | Application Default Credentials (ADC) via service account |
| Containerization | Docker Compose |
| ORM / Migrations | SQLAlchemy + Alembic |
| Structured logging | structlog |

---

## 3. Directory Structure

```
ai-service/
├── app/
│   ├── ai/                    # Vertex AI client + prompt templates
│   │   ├── vertex_client.py   # REST client with ADC auth, model tier + multimodal support
│   │   └── prompts/           # Markdown prompt files
│   │       ├── room_analysis.md
│   │       ├── design_strategy.md
│   │       ├── placement_planning.md
│   │       └── result_validation.md
│   ├── api/
│   │   ├── deps.py            # FastAPI dependency injection
│   │   └── routes/
│   │       ├── health.py      # GET  /health
│   │       ├── uploads.py     # POST /uploads/room-image
│   │       ├── design_jobs.py # POST /design-jobs, GET /design-jobs/{id}
│   │       └── products.py    # POST /products/search
│   ├── core/
│   │   ├── config.py          # Pydantic Settings (reads .env)
│   │   ├── constants.py       # Job status constants
│   │   ├── errors.py          # Custom exception hierarchy
│   │   └── logging.py         # structlog configuration
│   ├── db/
│   │   ├── session.py         # SQLAlchemy engine + session factory
│   │   ├── models/
│   │   │   ├── product.py         # Product (with enrichment columns)
│   │   │   ├── product_image.py   # ProductImage
│   │   │   ├── design_job.py      # DesignJob
│   │   │   ├── generated_design.py# GeneratedDesign
│   │   │   └── selected_product.py# SelectedProduct
│   │   └── repositories/
│   │       ├── product_repository.py
│   │       └── design_job_repository.py
│   ├── schemas/               # Pydantic request/response models
│   │   ├── ai_outputs.py      # RoomAnalysisResult, DesignStrategy, etc.
│   │   ├── design_job.py      # API request/response schemas
│   │   ├── product.py         # Product search schemas
│   │   ├── room.py            # RoomDimensions, UserPreferences
│   │   ├── placement.py       # Re-exports
│   │   └── common.py          # HealthResponse
│   ├── services/
│   │   ├── design_service.py  # Orchestrates job creation + result formatting
│   │   ├── product_service.py # Wraps vector search
│   │   └── upload_service.py  # Delegates to LocalImageStorage
│   ├── storage/
│   │   └── local_storage.py   # File I/O for room, product, generated images
│   ├── utils/
│   │   ├── geometry.py        # Polygon math (overlap, area, clamping)
│   │   ├── scoring.py         # Deterministic product scoring
│   │   ├── json_utils.py      # JSON extraction from AI output
│   │   └── image_utils.py     # Image helper stubs
│   ├── vector/
│   │   ├── qdrant.py          # QdrantClient factory
│   │   ├── collections.py     # Qdrant collection management (named vectors)
│   │   ├── product_indexer.py # Dual-vector embedding + Qdrant upsert
│   │   └── product_search.py  # Hybrid text + image similarity search
│   ├── workers/
│   │   ├── rq_worker.py       # RQ worker entrypoint
│   │   └── jobs.py            # Job dispatcher (run_design_job)
│   ├── workflow/
│   │   ├── graph.py           # LangGraph state machine builder
│   │   ├── state.py           # DesignWorkflowState TypedDict
│   │   └── nodes/             # Individual pipeline stages
│   │       ├── validate_input.py
│   │       ├── analyze_room.py
│   │       ├── create_design_strategies.py
│   │       ├── retrieve_candidates.py
│   │       ├── rerank_products.py
│   │       ├── plan_placements.py
│   │       ├── generate_images.py
│   │       ├── validate_result.py
│   │       ├── persist_result.py
│   │       └── helpers.py
│   └── main.py                # FastAPI application factory
├── scripts/                   # CLI scripts for setup
│   ├── import_enriched.py     # Import preprocessor output into DB
│   ├── import_products.py     # Import raw product JSON
│   ├── index_products_qdrant.py # Vectorize + upsert to Qdrant
│   └── create_qdrant_collections.py
├── migrations/                # Alembic migrations
├── secrets/                   # GCP service account key (gitignored)
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── pyproject.toml
├── .env / .env.example
├── SETUP.md                   # Setup instructions
└── SYSTEM.md                  # This file
```

---

## 4. API Specification

The API is self-documenting via **OpenAPI**. When the service is running, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

### Routes

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check. Returns `{"status": "ok"}`. |
| `POST` | `/uploads/room-image` | Upload a room photograph. Returns `{image_path, width, height}`. |
| `POST` | `/design-jobs` | Create a design job. Enqueues the AI pipeline. Returns `{job_id, status}`. |
| `GET` | `/design-jobs/{job_id}` | Poll job status. Returns full design results when completed. |
| `POST` | `/products/search` | Search the product catalog by semantic intent. |
| `GET` | `/images/{relative_path}` | Serves stored room, product, and generated images from `LOCAL_IMAGE_ROOT`. |

### Request/Response Schemas

#### POST /uploads/room-image
- **Request**: multipart/form-data with a `file` field (JPEG, PNG, or WebP, max 15 MB)
- **Response**: `{image_path: str, width: int, height: int}`

#### POST /design-jobs
- **Request body**:
  ```json
  {
    "room_image_path": "rooms/2026/05/abc123.jpg",
    "room_dimensions": {
      "unit": "cm",
      "current_wall_length_cm": 400,
      "room_depth_cm": 350,
      "ceiling_height_cm": 280
    },
    "preferences": {
      "mode": "auto_design",
      "design_style": "modern",
      "temperature": "warm",
      "colors": ["cream", "beige"]
    },
    "requested_design_count": 2
  }
  ```
- **Response**: `{job_id: UUID, status: "queued"}`

#### GET /design-jobs/{job_id}
- **Response** (when completed):
  ```json
  {
    "job_id": "...",
    "status": "completed",
    "designs": [
      {
        "design_id": "...",
        "title": "Warm Scandinavian Retreat",
        "style": "scandinavian",
        "summary": "...",
        "products": [
          {
            "product_id": "...",
            "external_id": "22DST2550CVPD",
            "name": "Destina Konsol",
            "category": "console_table",
            "brand": "İstikbal",
            "store_name": "İstikbal",
            "role": "console_table",
            "source_url": "https://...",
            "price": {"amount": 18370.0, "currency": "TL"},
            "reason": "Selected for warm tones and storage capability.",
            "score": 0.91
          }
        ],
        "clickable_regions": [
          {
            "region_id": "...",
            "type": "polygon",
            "polygon": [[260, 430], [480, 430], [500, 550], [240, 550]],
            "product_id": "..."
          }
        ]
      }
    ]
  }
  ```

#### POST /products/search
- **Request body**:
  ```json
  {
    "role": "dining_table",
    "category": "dining_table",
    "styles": ["modern"],
    "colors": ["cream"],
    "room_types": ["dining_room"],
    "query_text": "modern cream dining table",
    "limit": 10
  }
  ```
- **Response**: List of `ProductCandidate` objects with scores.

---

## 5. Workflow Pipeline

The design job pipeline is a **linear LangGraph state machine** with 9 nodes. Each node reads from and writes to a shared `DesignWorkflowState` dictionary.

```
validate_input → analyze_room → create_design_strategies → retrieve_candidates
    → rerank_products → plan_placements → generate_images → validate_result → persist_result
```

### State Schema

```python
class DesignWorkflowState(TypedDict, total=False):
    job_id: str
    room_image_path: str
    room_dimensions: dict
    user_preferences: dict
    requested_design_count: int
    room_analysis: dict          # Output of analyze_room
    design_strategies: list[dict] # Output of create_design_strategies
    retrieval_intents: list[dict] # Output of retrieve_candidates
    candidate_products: dict      # Output of retrieve_candidates
    selected_products: list[dict] # Output of rerank_products
    placement_plan: dict          # Output of plan_placements
    generated_images: list[dict]  # Output of generate_images
    final_designs: list[dict]     # Output of persist_result
    current_stage: str
    errors: list[dict]
```

### Node Details

| Node | AI Model | Description |
|---|---|---|
| `validate_input` | — | Checks job exists, image file present, clamps design count |
| `analyze_room` | **Pro** | Vision analysis of room photo: type, styles, furniture, zones |
| `create_design_strategies` | **Pro** | Generates creative design concepts based on room + preferences |
| `retrieve_candidates` | Text + Image embeddings | **Hybrid search**: text vectors via text-embedding-005 + image vectors via multimodalembedding@001. Passes room image for visual similarity matching. |
| `rerank_products` | — | Deterministic scoring: category, style, color, material fit |
| `plan_placements` | **Pro** | Spatial reasoning: assigns polygons per product in room image |
| `generate_images` | — | Stub (gated behind `ENABLE_IMAGE_GENERATION`) |
| `validate_result` | — | Verifies all products have required placement fields |
| `persist_result` | — | Saves final designs + selected products to PostgreSQL |

### Mock Mode

When `MOCK_AI=true` or `VERTEX_PROJECT_ID` is unset, AI-dependent nodes fall back to deterministic mocks. This enables local development without GCP credentials.

---

## 6. Data Models

### Product (PostgreSQL)

The `products` table stores enriched catalog data ingested from the preprocessor pipeline:

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Internal ID |
| `external_id` | Text (unique) | Catalog SKU |
| `name`, `description` | Text | Display name |
| `category` | Text (indexed) | Primary furniture category |
| `price_amount`, `price_currency` | Numeric, Text | Price |
| `styles`, `colors`, `material`, `room_types` | ARRAY(Text) | Filterable attributes |
| `temperature` | Text | warm/cold/neutral |
| `semantic_text` | JSONB | AI-generated captions (aesthetic, functional, material, attribute) |
| `shape` | JSONB | Shape metadata |
| `visual_features`, `design_tags`, `usage_intent` | ARRAY(Text) | Rich tags |
| `visual_weight`, `spatial_feel`, `quality_tier` | Text | Design properties |
| `is_active` | Boolean | Soft delete flag |

### ProductImage (PostgreSQL)

Stores image references per product. For enriched imports, `relative_path` contains the remote URL and `image_type` is `"remote"`.

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Internal ID |
| `product_id` | UUID (FK) | Parent product |
| `relative_path` | Text | Image URL or local path |
| `image_type` | Text | "remote" or "primary" |
| `is_primary` | Boolean | First image flag |

### DesignJob → GeneratedDesign → SelectedProduct

One-to-many chain: a design job produces multiple generated designs, each linking to selected products with placement polygons.

---

## 7. Vector Search Layer — Dual-Vector Hybrid Architecture

The system uses **two separate embedding spaces** stored as named vectors in a single Qdrant collection. This enables both semantic text matching and visual similarity matching.

### Qdrant Collection: `furniture_products`

| Named Vector | Dimensions | Model | Purpose |
|---|---|---|---|
| `text` | 768 | `text-embedding-005` | Semantic text similarity (full captions) |
| `image` | 1408 | `multimodalembedding@001` | Visual appearance similarity |

### Indexing (`product_indexer.py`)

For each product, two vectors are created:

1. **Text vector** (768-dim): Embedded from semantic_text captions (aesthetic + functional + material + attribute). These captions are rich, multi-sentence descriptions that capture the product's character. The `text-embedding-005` model handles up to 2048 tokens, so full captions are used.

2. **Image vector** (1408-dim): The product's primary local image file is read from `PRODUCT_EMBEDDING_IMAGE_ROOT` (default `/data/pipeline/output/images`) and uploaded inline to `multimodalembedding@001`. This captures the visual appearance — colors, textures, shapes, style — in a shared text-image embedding space without depending on source-store image URLs. Products without readable local images get a deterministic fallback vector.

Both vectors are upserted as named vectors in a single Qdrant point, along with a rich payload of filterable attributes.

### Search (`product_search.py`) — Hybrid Strategy

When a design job searches for products, the system performs **hybrid search**:

1. **Text search** (always): The query text (e.g., "modern cream dining table") is embedded via `text-embedding-005` and searched against the `"text"` named vector with Qdrant attribute filters.

2. **Image search** (when room image available): The uploaded room photograph is embedded via `multimodalembedding@001` and searched against the `"image"` named vector. This finds products whose appearance matches the room's visual style.

3. **Score merging**: Results from both searches are merged with weighted combination:
   - **Text similarity**: 60% weight (semantic meaning)
   - **Image similarity**: 40% weight (visual style match)

4. **Hybrid scoring**: The merged semantic score is combined with deterministic attribute matching:
   - Semantic similarity: 35%
   - Category match: 25%
   - Style match: 10%
   - Color match: 10%
   - Material match: 10%
   - Temperature fit: 5%
   - Room type fit: 5%

5. **Fallback cascade**: If vector search fails → SQL-based filtered search. If image search fails → text-only vector search.

### Why Two Models Instead of One?

- `text-embedding-005` (768-dim): Handles **full-length text** (up to 2048 tokens). Ideal for semantic captions.
- `multimodalembedding@001` (1408-dim): Handles **images** and short text (32 tokens max). Ideal for visual similarity. Text would be severely truncated, losing semantic depth.

Using both gives the best of both worlds: deep semantic understanding from text + visual style matching from images.

---

## 8. AI Integration

### Vertex AI Client (`vertex_client.py`)

- **Authentication**: Google ADC via service account key mounted at `/secrets/gcp-service-account.json`
- **Model tiers**:
  - `"pro"` → `gemini-3.1-pro-preview` — room analysis, design strategies, placement planning
  - `"flash"` → `gemini-3-flash-preview` — lightweight tasks, fallback
- **Output format**: All generate calls use `responseMimeType: "application/json"` for structured output
- **Retry**: Exponential backoff, 3 attempts

### Embedding Methods

| Method | Model | Use Case |
|---|---|---|
| `embed_texts()` | `text-embedding-005` | Batch text embedding for indexing and query |
| `embed_multimodal()` | `multimodalembedding@001` | Single image/text embedding for indexing and visual search |

The multimodal embedding endpoint requires a **region-specific URL** (`us-central1`), unlike the global endpoint used for text generation.

### Prompt Templates (`app/ai/prompts/`)

Each AI-powered node loads a markdown prompt template and appends context data (room analysis, preferences, products). Templates define the AI's role, task, expected output schema, and rules.

---

## 9. Task Queue

Design jobs are **asynchronous**. The API endpoint creates a job record, enqueues it to Redis via RQ, and returns a `job_id`. The worker process picks it up and runs the full LangGraph workflow.

- **Queue name**: `design_jobs`
- **Job timeout**: 30 minutes
- **Worker command**: `python -m app.workers.rq_worker`

Clients poll `GET /design-jobs/{job_id}` until `status` becomes `"completed"` or `"failed"`.

---

## 10. Infrastructure

### Docker Compose Services

| Service | Image | Purpose | Ports |
|---|---|---|---|
| `api` | Custom (Dockerfile) | FastAPI server | 8000 |
| `migrate` | Custom (Dockerfile) | One-shot Alembic schema migration | — |
| `worker` | Custom (Dockerfile) | RQ background worker | — |
| `postgres` | postgres:16 | Relational database | 5432 |
| `redis` | redis:7 | Task queue broker | 6379 |
| `qdrant` | qdrant/qdrant:latest | Vector database | 6333, 6334 |
| `adminer` | adminer:latest | DB admin UI | 8080 |

Compose orders database startup through the `migrate` service: PostgreSQL must pass `pg_isready`, `alembic upgrade head` must complete successfully, and only then do the API and worker start. This prevents request handlers from writing to missing tables such as `design_jobs` after a fresh server deployment. Manual migrations are still available with `make migrate` when needed.

### Volume Mounts

| Host Path | Container Path | Purpose |
|---|---|---|
| `./` | `/app` | Application code (hot reload) |
| `./data/images` | `/data/images` | Product + room + generated images |
| `./secrets` | `/secrets:ro` | GCP service account key |
| `../data` | `/data/pipeline:ro` | Preprocessor output and crawler-downloaded product images |

The API and worker run `scripts/docker-entrypoint.sh` before booting. It creates `LOCAL_IMAGE_ROOT`, `ROOM_UPLOAD_DIR`, `PRODUCT_IMAGE_DIR`, and `GENERATED_IMAGE_DIR` and relaxes permissions on those mounted directories when the filesystem allows it. `make up` also runs `prepare-docker-dirs` on the host so the default `./data/images` bind mount is not created as a root-owned Docker directory.

Product image embeddings read crawler-downloaded images from `PRODUCT_EMBEDDING_IMAGE_ROOT`, defaulting to `/data/pipeline/output/images`, which corresponds to host `../data/output/images`. If the service is deployed with a different data mount, update `PRODUCT_EMBEDDING_IMAGE_ROOT` together with the compose mount. API image responses must remain relative to `LOCAL_IMAGE_ROOT`.

### Portability Notes

The system is designed to move between local dev and production servers:

1. **No hardcoded hosts**: All service URLs (DB, Redis, Qdrant) are configured via `.env`
2. **ADC authentication**: GCP credentials are injected via mounted service account key, not embedded
3. **Data pipeline mount**: The preprocessor output is read-only mounted, not copied
4. **Stateless containers**: All state lives in PostgreSQL, Qdrant, and Redis volumes
5. **Environment parity**: The same Docker Compose file works on any Linux host with Docker installed
6. **Region-aware**: Multimodal embeddings use `us-central1` endpoint (configurable via `VERTEX_MULTIMODAL_LOCATION`)

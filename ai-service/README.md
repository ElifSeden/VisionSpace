# Furniture AI Backend

Production-minded FastAPI backend for an agentic RAG furniture recommendation and room-design workflow.

## Quick start

```bash
cp .env.example .env
make up
make migrate
make create-qdrant
make worker
```

API:

- `GET /health`
- `POST /uploads/room-image`
- `POST /design-jobs`
- `GET /design-jobs/{job_id}`
- `POST /products/search`

The workflow runs through RQ + Redis and is mocked by default unless `GEMINI_API_KEY` is set and `MOCK_AI=false`.

Full setup, test commands, and missing production inputs are documented in [SETUP.md](SETUP.md).

## Import products

```bash
make import-products file=/path/to/products.json
make index-products
```

Product image paths are stored as relative paths only. Configure image roots in `.env`.

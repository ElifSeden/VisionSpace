# Setup And Verification

This backend is designed to run on Ubuntu 24.04 LTS with Docker Compose. The crawler and preprocessing outputs are assumed to already exist and are not part of this project.

## 1. Install Server Dependencies

From `ai-service/`:

```bash
sudo bash scripts/install_ubuntu_24_04.sh
```

The script installs Docker, Docker Compose, `git`, `make`, and Python basics, creates image directories, and copies `.env.example` to `.env` if needed.

## 2. Configure `.env`

Required before running:

```bash
cp .env.example .env
```

Review these values:

- `PRODUCT_IMAGE_DIR`: set this to the product image directory on the target server.
- `LOCAL_IMAGE_ROOT`: parent image root mounted into Docker, default `/data/images`.
- `GEMINI_API_KEY`: set this for real Gemini calls.
- `MOCK_AI`: keep `true` for the mocked workflow; set `false` only after real AI stages are implemented and configured.
- `ENABLE_IMAGE_GENERATION`: keep `false` for now. Product identity and polygons work without generated images.

## 3. Start Services

```bash
make up
make migrate
make create-qdrant
```

Check API health:

```bash
curl http://localhost:8000/health
```

Expected:

```json
{"status":"ok"}
```

## 4. Import Product Data

For a smoke test with demo data:

```bash
make import-products file=samples/products.demo.json
make index-products
```

For real data:

```bash
make import-products file=/path/to/products.json
make index-products
```

The importer expects the tolerant JSON array shape described in `TEMP.md`. Existing products are updated by `external_id`.

## 5. Run Worker

The worker starts with Compose by default. To run it manually:

```bash
make worker
```

## 6. Upload The Provided Image

The provided image is at `../TEMP/input.jpeg` from this directory.

```bash
curl -F "file=@../TEMP/input.jpeg" http://localhost:8000/uploads/room-image
```

The response returns a relative image path like:

```json
{
  "image_path": "rooms/2026/05/abc.jpeg",
  "width": 1280,
  "height": 720
}
```

Use that `image_path` when creating a design job.

## 7. Create A Design Job

```bash
curl -X POST http://localhost:8000/design-jobs \
  -H "Content-Type: application/json" \
  -d '{
    "room_image_path": "rooms/2026/05/replace_with_upload_response.jpeg",
    "room_dimensions": {
      "unit": "cm",
      "current_wall_length_cm": 420,
      "room_depth_cm": 360,
      "ceiling_height_cm": 270,
      "known_reference_objects": []
    },
    "preferences": {
      "mode": "auto_design",
      "replace_existing_furniture": true,
      "requested_furniture_types": ["coffee_table", "carpet", "floor_lamp"],
      "replace_targets": [],
      "design_style": "scandinavian",
      "material": "wood",
      "colors": ["beige", "oak"],
      "temperature": "warm",
      "size": "medium",
      "budget": null,
      "extra_preferences": "cozy but minimal"
    },
    "requested_design_count": 1
  }'
```

Then poll:

```bash
curl http://localhost:8000/design-jobs/<job_id>
```

## 8. Local Developer Checks

Without Docker:

```bash
python3 -m compileall app scripts tests
pytest -q
docker compose config
```

These checks validate syntax, utility behavior, schemas, storage path handling, Qdrant filter construction, and Compose wiring.

## Missing Or Needs Your Input

- Real product catalog JSON: required for useful recommendations.
- Product image directory: set `PRODUCT_IMAGE_DIR` to the final target server path.
- Gemini API key: required for real AI stages.
- Real Gemini room analysis and placement planning: current workflow uses mocked room analysis and deterministic placement so the backend can run end-to-end safely first.
- True embedding generation: Qdrant indexing currently uses deterministic placeholder vectors; replace with real embedding generation when the chosen embedding model is finalized.
- Image generation/editing: intentionally disabled unless `ENABLE_IMAGE_GENERATION=true`; the implementation currently keeps generated image creation as a future gated step.
- Production secrets: replace default Postgres password and any placeholder keys before deployment.


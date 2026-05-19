# VisionSpace AI Service System Design

This service has two main subsystems: `crawler/` collects raw furniture product data, and `preprocessor/` normalizes and enriches that raw data. The expected data flow is:

1. Run the Scrapy crawler from `data/scraping.py`, `data/crawler/run.py`, or `data/crawler/run_all.py`.
2. The crawler writes scraped products to `data/output/products.jsonl` and downloaded images to `data/output/images/`.
3. Run `data/preprocessor/run.py` or `data/preprocessor/enrich_products.py` to transform raw products into normalized enriched product records.

## Crawler Design

The crawler is a Scrapy project flattened into the `crawler/` directory. There is no nested package directory. Scrapy loads `crawler/scrapy.cfg`, which points at `settings.py` in the same directory.

### Entrypoints

`data/scraping.py` is the top-level convenience entrypoint for one spider. It runs `scrapy crawl <spider>` with `cwd` set to `data/crawler/`, and accepts `--target-per-category` or `--until-finished`.

`data/crawler/run.py` is the interactive crawler runner. It asks which spiders, which accepted categories, and whether to scrape a fixed product count per selected category or continue until every selected category is exhausted.

`data/crawler/run_all.py` is the non-interactive multi-spider entrypoint. It imports the spider classes directly from `crawler/spiders/` and schedules Ikea, Vivense, and Istikbal in a single `CrawlerProcess`.

### Scrapy Settings

`crawler/settings.py` defines the Scrapy runtime:

- `BOT_NAME = "crawler"`.
- `SPIDER_MODULES = ["spiders"]` because spiders are now directly under `crawler/spiders/`.
- `ITEM_PIPELINES` runs three ordered stages:
  - `pipelines.DuplicatesPipeline` rejects invalid or duplicate products.
  - `pipelines.FurnitureImagePipeline` downloads product images and writes local image paths back to the item.
  - `pipelines.JsonExportPipeline` writes the final raw item as JSONL output.
- `PROJECT_ROOT` is added to `sys.path` so Scrapy can resolve local package imports while running from inside `crawler/`.
- `IMAGES_STORE` points to `data/output/images`.

### Items

`crawler/items.py` defines `FurnitureItem`, the shared item contract emitted by all spiders. Important fields:

- Identity and metadata: `id`, `name`, `url`, `metadata`.
- Commercial data: `price`, `currency`.
- Descriptive data: `description`, `category`, optional `attributes`, optional `breadcrumbs`.
- Image data: `image_urls`, `images`, `image_paths`.

Spiders should fill as much raw product information as possible and leave taxonomy normalization, dimensions, and semantic captions to preprocessing. `category` is the selected accepted crawler category such as `kitchen` or `living_room`; breadcrumbs may be recorded for raw traceability but must not drive category acceptance or preprocessor enrichment.


### Raw Product JSON Schema

Crawler output records should follow this raw product shape before preprocessing. The crawler writes one object per line to `data/output/products.jsonl`. Some fields are optional because source pages differ and Scrapy only serializes fields present on the item.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "RawFurnitureProduct",
  "type": "object",
  "required": [
    "url",
    "category",
    "name",
    "description",
    "price",
    "currency",
    "id",
    "metadata",
    "image_urls"
  ],
  "properties": {
    "url": {
      "type": "string",
      "format": "uri",
      "description": "Canonical product page URL."
    },
    "category": {
      "type": "string",
      "description": "Selected crawler accepted category, e.g. kitchen or living_room. The preprocessor stores this as source_category and infers product taxonomy separately."
    },
    "name": {
      "type": "string",
      "description": "Product display name."
    },
    "description": {
      "type": "string",
      "description": "Raw product description from the source."
    },
    "price": {
      "type": "string",
      "description": "Raw product price as scraped. Keep as string at crawler boundary to avoid locale/format loss."
    },
    "currency": {
      "type": "string",
      "description": "Currency code or source currency label."
    },
    "id": {
      "type": "string",
      "description": "Stable source product identifier, SKU, MPN, or generated deterministic id."
    },
    "metadata": {
      "type": "object",
      "description": "Raw structured metadata extracted from the page, usually JSON-LD Product data.",
      "properties": {
        "@context": {
          "type": "string"
        },
        "@type": {
          "type": "string"
        },
        "name": {
          "type": "string"
        },
        "image": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "brand": {
          "type": "object",
          "properties": {
            "@type": {
              "type": "string"
            },
            "name": {
              "type": "string"
            }
          },
          "additionalProperties": true
        },
        "sku": {
          "type": "string"
        },
        "mpn": {
          "type": "string"
        },
        "offers": {
          "type": "object",
          "properties": {
            "@type": {
              "type": "string"
            },
            "priceCurrency": {
              "type": "string"
            },
            "price": {
              "type": "string"
            },
            "availability": {
              "type": "string"
            },
            "itemCondition": {
              "type": "string"
            },
            "url": {
              "type": "string"
            }
          },
          "additionalProperties": true
        }
      },
      "additionalProperties": true
    },
    "image_urls": {
      "type": "array",
      "description": "Remote product image URLs collected by the crawler.",
      "items": {
        "type": "string",
        "format": "uri"
      },
      "minItems": 0
    },
    "breadcrumbs": {
      "type": "array",
      "description": "Optional raw breadcrumb labels captured from the product page for traceability. They are not used for crawler category acceptance or preprocessor taxonomy inference.",
      "items": {
        "type": "string"
      }
    },
    "attributes": {
      "type": "object",
      "description": "Lightweight crawl-time attributes. Rich enrichment happens later in preprocessor/enrich_products.py.",
      "required": [
        "color",
        "material",
        "style",
        "room",
        "temperature",
        "size"
      ],
      "properties": {
        "color": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "material": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "style": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "room": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "temperature": {
          "type": "string"
        },
        "size": {
          "type": "string"
        }
      },
      "additionalProperties": true
    }
  },
  "additionalProperties": true
}
```

Example valid raw product record:

```json
{
  "url": "https://www.istikbal.com.tr/urun/essen-mutfak-masa-takimi-1",
  "category": "kitchen",
  "name": "Essen Mutfak Masa Takımı Siyah",
  "description": "Essen Mutfak Masa Takımı Siyah: 49754-2|49784-1",
  "price": "23440",
  "currency": "TL",
  "id": "58ESSE0200001",
  "metadata": {
    "@context": "https://schema.org",
    "@type": "Product",
    "name": "Essen Mutfak Masa Takımı Siyah",
    "image": "https://www.istikbal.com.tr/idea/kc/80/myassets/products/056/essen-mutfak-masa-sandalye-03.jpg?revision=1762255818",
    "description": "Essen Mutfak Masa Takımı Siyah: 49754-2|49784-1",
    "brand": {
      "@type": "Brand",
      "name": "İstikbal"
    },
    "sku": "58ESSE0200001",
    "mpn": "58ESSE0200001",
    "offers": {
      "@type": "Offer",
      "priceCurrency": "TL",
      "price": "23440",
      "availability": "https://schema.org/InStock",
      "itemCondition": "https://schema.org/NewCondition",
      "url": "https://www.istikbal.com.tr/urun/essen-mutfak-masa-takimi-1"
    }
  },
  "image_urls": [
    "https://www.istikbal.com.tr/idea/kc/80/myassets/products/056/essen-mutfak-masa-sandalye-03.jpg?revision=1762255818",
    "https://www.istikbal.com.tr/idea/kc/80/myassets/products/056/essen-mutfak-masa-sandalye-03.jpg"
  ],
  "breadcrumbs": [
    "Ana Sayfa",
    "Yemek Odası",
    "Mutfak Masa Takımları"
  ]
}
```

Raw crawler output should keep source values intact. The crawler no longer accepts products by breadcrumb matching; it starts from direct accepted category URLs and only queues product links found in scoped all-products list containers. Type conversion, taxonomy normalization, confidence scoring, semantic text generation, and richer attributes belong to the preprocessor layer.

### Extractors

`crawler/extractors/` contains reusable parser helpers:

- `jsonld_extractor.py` reads JSON-LD product metadata from pages and extracts product-like objects.
- `image_extractor.py` collects image URLs from product pages.

Spiders should prefer these helpers over duplicating JSON-LD or image parsing logic.

### Spiders

`crawler/spiders/` contains one spider per source:

- `vivense_spider.py`
- `ikea_spider.py`
- `istikbal_spider.py`

Each spider imports `FurnitureItem`, JSON-LD extractors, and image extractors through the flattened crawler imports, for example `from items import FurnitureItem`.

All source spiders inherit from `RoundRobinCategorySpider`. Accepted categories are direct target category URLs, currently `kitchen` and `living_room`. The base spider starts every selected category page, queues product URLs from source-specific all-products selectors, and alternates product requests in round-robin order so one category cannot consume the whole target before the others. Breadcrumbs may be stored on product items, but they are not used to decide whether a product belongs to a selected category.

Source-specific category behavior:

- `vivense_spider.py`: queues products from `#product-list-wrapper .product-list .product-card[data-url]`, which scopes scraping to the all-products grid and avoids recommendation/deal/promo sections.
- `istikbal_spider.py`: queues products from `.showcase-container .showcase .showcase-title a` and follows pagination from `link[rel="next"]` or pagination next selectors.
- `ikea_spider.py`: starts from the direct category page, reads or falls back to the IKEA category API id, then pages through `https://frontendapi.ikea.com.tr/api/search/products`. IKEA API rows with `type == "cbm"` are skipped as content/marketing blocks, and product URLs are normalized back to `https://www.ikea.com.tr/urun/...`.

### Crawler Pipelines

`crawler/pipelines.py` keeps crawler-native output concerns:

- `DuplicatesPipeline` requires `id` and `name`, normalizes ids to uppercase, and drops duplicate ids or duplicate base names.
- `FurnitureImagePipeline` subclasses Scrapy `ImagesPipeline`. It stores downloaded images under `products/<PRODUCT_ID>/<image_name>` and writes successful local paths back to `local_image_paths`.
- `JsonExportPipeline` writes each final Scrapy item as one JSON object per line in `data/output/products.jsonl`.

Preprocessing/enrichment logic should not be added to `crawler/pipelines.py`; it belongs in `preprocessor/`.

## Preprocessor Design

The `preprocessor/` package owns enrichment, AI calling, and schema normalization.

### Package Layout

- `preprocessor/models.py`: Pydantic schemas and taxonomies for normalized product data.
- `preprocessor/enrich_products.py`: Batch enrichment CLI for raw crawler JSONL.
- `preprocessor/run.py`: interactive wrapper for choosing parallel request count and product limit.
- `preprocessor/crawler_pipelines.py`: legacy Scrapy-compatible preprocessing pipeline; not enabled by current crawler settings.
- `preprocessor/vertex_ai.py`: Shared Vertex AI REST client.
- `preprocessor/labeler.py`: Image-aware product labeler backed by Vertex AI.

### Data Model

`preprocessor/models.py` is the canonical schema layer. It defines taxonomies for category, style, room, material, color, temperature, spatial feel, visual weight, verification status, and brand.

Important models:

- `ProductRaw`: normalized representation of a scraped input row before enrichment. It keeps the crawler category in `source_category` and reserves `category` for product-type hints from product metadata when available.
- `FurnitureAttributes`: structured output for category, style, color, material, dimensions, room compatibility, shape, visual features, tags, spatial feel, visual weight, texture, contrast, usage intent, quality tier, and assembly status.
- `SemanticText`: generated captions used for retrieval and vector text.
- `EnrichedProduct`: final enriched record written by `enrich_products.py`.

Validators clamp confidence values to `[0.0, 1.0]` and normalize taxonomy values. This means Vertex AI may return imperfect labels, but Pydantic validation forces them back into supported labels or `unknown`.

### Batch Enrichment

`preprocessor/enrich_products.py` is the main preprocessor CLI:

```bash
cd data
python preprocessor/enrich_products.py --input output/products.jsonl --output enriched_products.jsonl --parallel-requests 4
```

Its internal flow is:

1. Load `.env` from `preprocessor/.env` and the repository `.env`.
2. Resolve the input JSONL path. It searches the current path, `preprocessor/`, `preprocessor/output/`, repo root, and repo parent paths.
3. Iterate input rows safely. Invalid JSON rows are written to the error file.
4. Normalize raw rows into `ProductRaw` with stable ids, inferred brand, normalized price, currency, image URLs, raw metadata, and `source_category` copied from the crawler `category` field.
5. If `PROJECT_ID` is set, try Vertex AI enrichment through `VertexEnricher`.
6. If Vertex AI is unavailable or a single product request fails, use deterministic fallback enrichment.
7. Process rows with up to `--parallel-requests` worker threads. Each worker receives one raw row and returns either one output line or one error payload.
8. Write output JSONL and error JSONL only from the main thread, preserving input order and avoiding shared file-handle races.

The deterministic fallback is intentional. It keeps local development and crawler testing functional without cloud credentials. It infers product category from product name, description, URL, and metadata, not from breadcrumbs. `source_category` is used only as a room-compatibility hint. `preprocessor/run.py` asks for “How many parallel requests?” and “How many to preprocess in JSON file? (all, or amount)” before calling `enrich_file()`.

### Vertex AI Client

`preprocessor/vertex_ai.py` is the only module that should know how to call Vertex AI directly. It uses Google Application Default Credentials, not API keys.

Configuration comes from environment variables:

- `PROJECT_ID`: Google Cloud project id, for example `decorator-ai`.
- `MODEL_ID`: Vertex publisher model id, for example `gemini-3-flash-preview`.
- `VERTEX_LOCATION`: optional, defaults to `global`.

The endpoint format is:

```text
https://aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/{LOCATION}/publishers/google/models/{MODEL_ID}:streamGenerateContent
```

`VertexAIClient.stream_generate_content()` sends:

- `contents.role = "user"`
- `contents.parts = [...]`
- `generationConfig.temperature`
- optional `generationConfig.responseMimeType = "application/json"`

The client refreshes an ADC token with the `https://www.googleapis.com/auth/cloud-platform` scope and sends it as a Bearer token.

Streaming responses are normalized by `extract_text_from_stream_response()`, which accepts both JSON array responses and line-oriented streamed responses. It concatenates all candidate text parts.

### Vertex Enrichment Prompt

`build_vertex_prompt()` in `enrich_products.py` asks the model to return only JSON with these top-level keys:

- `attributes`
- `semantic_text`

The prompt includes all supported taxonomy labels and a concrete JSON shape. The model is expected to generate structured enrichment while not inventing exact dimensions, URL, brand, price, or currency.

`VertexEnricher` validates the response with:

- `FurnitureAttributes.model_validate(...)`
- `SemanticText.model_validate(...)`

If validation fails, the caller catches the exception and falls back to deterministic enrichment for that product.

### Image Labeler

`preprocessor/labeler.py` is a smaller Vertex AI labeling path used by `agent_pipeline.py`. It supports image parts:

- Local files are sent as Vertex `inlineData` with base64 content.
- `gs://...` paths are sent as Vertex `fileData` with a MIME type.

The labeler returns a compact `FurnitureAttributes` schema local to `labeler.py`. This is separate from the richer `FurnitureAttributes` in `models.py` and is kept for the older agent pipeline workflow.

### Crawler/Preprocessor Boundary

The crawler does not run preprocessor enrichment during normal crawls. `crawler/settings.py` only enables crawler-native duplicate filtering, image downloading, and JSONL export. Raw crawler output should keep source values intact, including selected source category and optional breadcrumbs when present.

`preprocessor/crawler_pipelines.py` remains as a legacy Scrapy-compatible pipeline, but it is not imported by current crawler settings. Rich schema enrichment, taxonomy normalization, dimensions, semantic captions, and Vertex enrichment calls happen after crawling through `preprocessor/enrich_products.py`.

Product embeddings are intentionally not built in the data preprocessor. `ai-service` imports `enriched_products.jsonl`, generates Vertex text/image embeddings, and writes the active Qdrant vectors during backend indexing.

## Environment and Auth Expectations

A typical `.env` for generation is:

```bash
PROJECT_ID=decorator-ai
MODEL_ID=gemini-3-flash-preview
```

No `GEMINI_API_KEY` is used. Authentication is provided by Google Application Default Credentials on the machine running the scripts.

## Operational Notes for AI Agents

- Keep crawler source-specific parsing in `crawler/spiders/` or `crawler/extractors/`.
- Keep schema enrichment, AI prompts, and Vertex enrichment calls in `preprocessor/`.
- Do not reintroduce direct Vertex HTTP calls outside `preprocessor/vertex_ai.py`.
- Do not add API-key based Gemini calls. This project uses Vertex AI with ADC.
- Preserve JSONL as the boundary between crawler and preprocessor.
- Do not reintroduce breadcrumb-based crawler filtering or breadcrumb-based preprocessor category inference; use direct accepted category URLs and product-list selectors in the crawler, and product text/metadata plus `source_category` hints in the preprocessor.
- Keep parallel preprocessing writes centralized in the main thread; worker threads may call Vertex AI and build result payloads, but must not write shared output files.
- Preserve deterministic fallback enrichment so local runs still work without cloud access.
- When adding new enriched fields, update `preprocessor/models.py`, the Vertex prompt JSON shape, fallback enrichment, and this document.

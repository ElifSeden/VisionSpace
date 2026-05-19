import time
from pathlib import Path
from urllib.parse import unquote, urlparse

import structlog
from qdrant_client.http import models
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import get_settings
from app.db.models.product import Product
from app.vector.collections import ensure_product_collection
from app.vector.qdrant import get_qdrant_client

logger = structlog.get_logger(__name__)

EMBEDDING_BATCH_SIZE = 50
MIN_IMAGE_BYTES = 1000
MAX_IMAGE_BYTES = 10 * 1024 * 1024


def build_embedding_text(product: Product) -> str:
    """Build the text to embed for a product.

    Prefers the rich semantic_text captions from the preprocessor when available,
    falling back to a simpler concatenation of product fields.
    """
    semantic = product.semantic_text or {}
    captions = [
        semantic.get("aesthetic_caption", ""),
        semantic.get("functional_caption", ""),
        semantic.get("material_caption", ""),
        semantic.get("attribute_caption", ""),
    ]
    caption_text = " ".join(c.strip() for c in captions if c and c.strip())
    if caption_text:
        return caption_text

    # Fallback for products without semantic_text
    return "\n".join(
        [
            f"Name: {product.name}",
            f"Category: {product.category}",
            f"Description: {product.description or ''}",
            f"Styles: {', '.join(product.styles or [])}",
            f"Material: {', '.join(product.material or [])}",
            f"Colors: {', '.join(product.colors or [])}",
            f"Temperature: {product.temperature or ''}",
            f"Room types: {', '.join(product.room_types or [])}",
            f"Dimensions: {product.width_cm}x{product.depth_cm}x{product.height_cm} cm",
        ]
    )


def deterministic_vector(text: str, size: int) -> list[float]:
    """Deterministic placeholder vector for environments without Vertex AI."""
    values = [0.0] * size
    for index, byte in enumerate(text.encode("utf-8")):
        values[index % size] += (byte % 31) / 31.0
    norm = sum(v * v for v in values) ** 0.5 or 1.0
    return [v / norm for v in values]


def _build_payload(product: Product, text: str) -> dict:
    primary = next(
        (img for img in product.images if img.is_primary),
        product.images[0] if product.images else None,
    )
    return {
        "product_db_id": str(product.id),
        "external_id": product.external_id,
        "category": product.category,
        "styles": product.styles or [],
        "material": product.material or [],
        "colors": product.colors or [],
        "temperature": product.temperature,
        "room_types": product.room_types or [],
        "width_cm": float(product.width_cm) if product.width_cm is not None else None,
        "depth_cm": float(product.depth_cm) if product.depth_cm is not None else None,
        "height_cm": float(product.height_cm) if product.height_cm is not None else None,
        "visual_weight": product.visual_weight,
        "spatial_feel": product.spatial_feel,
        "quality_tier": product.quality_tier,
        "design_tags": product.design_tags or [],
        "is_group": product.is_group,
        "is_active": product.is_active,
        "embedding_text": text,
        "primary_image_path": primary.relative_path if primary else None,
    }


def _ordered_product_images(product: Product):
    return sorted(
        product.images,
        key=lambda img: (not bool(img.is_primary), getattr(img, "sort_order", 0) or 0),
    )


def _relative_from_source_url(product: Product, source: str) -> str | None:
    """Map a previously imported remote URL to the crawler image path convention."""
    parsed = urlparse(source)
    filename = Path(unquote(parsed.path)).name
    if not filename or not product.external_id:
        return None
    return f"products/{product.external_id}/{filename}"


def _candidate_relative_image_paths(product: Product) -> list[str]:
    candidates = []
    seen = set()
    for image in _ordered_product_images(product):
        relative_path = image.relative_path.strip()
        if relative_path.startswith(("http://", "https://")):
            candidate = _relative_from_source_url(product, relative_path)
        else:
            candidate = relative_path
        if candidate and candidate not in seen:
            candidates.append(candidate)
            seen.add(candidate)
    return candidates


def _safe_relative_path(relative_path: str) -> Path | None:
    path = Path(relative_path)
    if path.is_absolute() or ".." in path.parts:
        return None
    return path


def _candidate_absolute_image_paths(relative_path: str, settings) -> list[Path]:
    path = _safe_relative_path(relative_path)
    if path is None:
        return []

    roots = [settings.product_embedding_image_root, settings.local_image_root]
    if path.parts and path.parts[0] == "products":
        roots.append(settings.product_image_dir.parent)
    else:
        roots.append(settings.product_image_dir)

    candidates = []
    seen = set()
    for root in roots:
        absolute = (root / path).resolve()
        if absolute not in seen:
            candidates.append(absolute)
            seen.add(absolute)
    return candidates


def _read_image_bytes(product: Product, settings) -> tuple[bytes | None, Path | None]:
    for relative_path in _candidate_relative_image_paths(product):
        for absolute_path in _candidate_absolute_image_paths(relative_path, settings):
            try:
                if not absolute_path.is_file():
                    continue
                data = absolute_path.read_bytes()
            except OSError:
                continue
            if MIN_IMAGE_BYTES <= len(data) <= MAX_IMAGE_BYTES:
                return data, absolute_path
    return None, None


def index_products(db: Session, include_inactive: bool = False) -> int:
    """Index products into Qdrant with dual vectors: text + image.

    Text vector (768-dim): from text-embedding-005, captures semantic meaning.
    Image vector (1408-dim): from multimodalembedding@001, captures visual appearance.
    """
    settings = get_settings()
    ensure_product_collection()
    client = get_qdrant_client()

    stmt = select(Product).options(selectinload(Product.images))
    if not include_inactive:
        stmt = stmt.where(Product.is_active.is_(True))
    products = list(db.scalars(stmt))

    if not products:
        logger.info("no_products_to_index")
        return 0

    # Build embedding texts
    texts = [build_embedding_text(p) for p in products]

    # --- Text vectors (768-dim via text-embedding-005) ---
    use_vertex = bool(settings.vertex_project_id)
    if use_vertex:
        logger.info(
            "embedding_text_with_vertex_ai",
            model=settings.vertex_embedding_model,
            count=len(texts),
        )
        text_vectors = _vertex_embed_text_batch(texts, settings)
    else:
        logger.info("embedding_text_with_deterministic_fallback", count=len(texts))
        text_vectors = [deterministic_vector(t, settings.qdrant_text_vector_size) for t in texts]

    # --- Image vectors (1408-dim via multimodalembedding@001) ---
    if use_vertex:
        logger.info(
            "embedding_images_with_multimodal",
            model=settings.vertex_multimodal_model,
            count=len(products),
        )
        image_vectors = _embed_product_images(products, settings)
    else:
        logger.info("embedding_images_with_deterministic_fallback", count=len(products))
        image_vectors = [deterministic_vector(t, settings.qdrant_image_vector_size) for t in texts]

    # Build and upsert Qdrant points with named vectors
    points = []
    image_success = 0
    for product, text, text_vec, image_vec in zip(products, texts, text_vectors, image_vectors):
        if image_vec is not None:
            image_success += 1
        points.append(
            models.PointStruct(
                id=str(product.id),
                vector={
                    "text": text_vec,
                    "image": image_vec
                    if image_vec
                    else deterministic_vector(text, settings.qdrant_image_vector_size),
                },
                payload=_build_payload(product, text),
            )
        )

    # Upsert in batches
    batch_size = 100
    for i in range(0, len(points), batch_size):
        batch = points[i : i + batch_size]
        client.upsert(collection_name=settings.qdrant_collection_products, points=batch)

    logger.info(
        "indexed_products",
        count=len(points),
        images_embedded=image_success,
        method="vertex" if use_vertex else "deterministic",
    )
    return len(points)


def _vertex_embed_text_batch(texts: list[str], settings) -> list[list[float]]:
    """Embed texts in batches using Vertex AI text embedding endpoint."""
    from app.ai.vertex_client import VertexAIClient

    client = VertexAIClient(settings)
    all_vectors: list[list[float]] = []

    for i in range(0, len(texts), EMBEDDING_BATCH_SIZE):
        batch = texts[i : i + EMBEDDING_BATCH_SIZE]
        vectors = client.embed_texts(batch)
        all_vectors.extend(vectors)
        logger.info("embedded_text_batch", start=i, count=len(batch))
        time.sleep(1)  # Rate limit pacing

    return all_vectors


def _embed_product_images(products: list[Product], settings) -> list[list[float] | None]:
    """Embed primary product images from local crawler image files.

    Returns a list parallel to `products`. Each entry is either a 1408-dim
    vector or None if no readable local image file could be found or embedded.
    """
    from app.ai.vertex_client import VertexAIClient

    client = VertexAIClient(settings)
    results: list[list[float] | None] = []

    for i, product in enumerate(products):
        image_bytes, image_path = _read_image_bytes(product, settings)
        if not image_bytes:
            logger.warning(
                "product_image_file_missing",
                product_id=str(product.id),
                image_paths=_candidate_relative_image_paths(product),
            )
            results.append(None)
            continue

        try:
            vector = client.embed_multimodal(
                image_bytes=image_bytes,
                dimension=settings.qdrant_image_vector_size,
            )
            results.append(vector)
        except Exception as exc:
            logger.warning(
                "image_embed_failed",
                product_id=str(product.id),
                image_path=str(image_path),
                error=str(exc),
            )
            results.append(None)

        if (i + 1) % 20 == 0:
            logger.info("image_embed_progress", done=i + 1, total=len(products))

    return results

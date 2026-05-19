from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.models.product import Product
from app.db.repositories.product_repository import ProductRepository
from app.schemas.ai_outputs import ProductRetrievalIntent
from app.schemas.product import ProductCandidate
from app.utils.scoring import score_product


def product_to_candidate(product: Product, intent: ProductRetrievalIntent, semantic_score: float = 0.0) -> ProductCandidate:
    primary = next((img for img in product.images if img.is_primary), product.images[0] if product.images else None)
    score = score_product(product, intent, semantic_score)
    return ProductCandidate(
        product_id=product.id,
        external_id=product.external_id,
        name=product.name,
        category=product.category,
        source_url=product.source_url,
        image_path=primary.relative_path if primary else None,
        semantic_score=semantic_score,
        score=score,
        metadata={
            "styles": product.styles or [],
            "colors": product.colors or [],
            "material": product.material or [],
            "temperature": product.temperature,
            "room_types": product.room_types or [],
            "width_cm": float(product.width_cm) if product.width_cm is not None else None,
            "depth_cm": float(product.depth_cm) if product.depth_cm is not None else None,
            "height_cm": float(product.height_cm) if product.height_cm is not None else None,
        },
    )


def build_filter_payload(intent: ProductRetrievalIntent) -> dict:
    payload = {"must": [{"key": "category", "match": {"value": intent.category}}, {"key": "is_active", "match": {"value": True}}]}
    if not intent.is_group_allowed:
        payload["must"].append({"key": "is_group", "match": {"value": False}})
    for field in ("styles", "material", "colors", "room_types"):
        values = getattr(intent, field)
        if values:
            payload["must"].append({"key": field, "match": {"any": values}})
    if intent.temperature:
        payload["must"].append({"key": "temperature", "match": {"value": intent.temperature}})
    return payload


def search_products(db: Session, intent: ProductRetrievalIntent, limit: int | None = None) -> list[ProductCandidate]:
    settings = get_settings()
    effective_limit = limit or settings.max_candidates_per_item
    # MVP fallback. Qdrant collection/indexing exists, but runtime search stays reliable without embeddings.
    products = ProductRepository(db).fallback_search(intent, effective_limit)
    return sorted(
        [product_to_candidate(product, intent, 0.0) for product in products],
        key=lambda candidate: candidate.score,
        reverse=True,
    )


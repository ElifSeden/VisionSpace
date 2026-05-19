from app.db.models.product import Product
from app.schemas.ai_outputs import ProductRetrievalIntent


def score_product(product: Product, intent: ProductRetrievalIntent, semantic_score: float = 0.0) -> float:
    score = semantic_score * 0.35
    score += 0.25 if product.category == intent.category else 0
    score += 0.1 if set(product.styles or []) & set(intent.styles) else 0
    score += 0.1 if set(product.colors or []) & set(intent.colors) else 0
    score += 0.1 if set(product.material or []) & set(intent.material) else 0
    score += 0.05 if not intent.temperature or product.temperature in {intent.temperature, None} else 0
    score += 0.05 if set(product.room_types or []) & set(intent.room_types) or not intent.room_types else 0
    return round(min(score, 1.0), 4)


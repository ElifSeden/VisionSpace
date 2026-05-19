from qdrant_client.http import models
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.models.product import Product
from app.vector.collections import ensure_product_collection
from app.vector.qdrant import get_qdrant_client


def build_embedding_text(product: Product) -> str:
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
    values = [0.0] * size
    for index, byte in enumerate(text.encode("utf-8")):
        values[index % size] += (byte % 31) / 31.0
    norm = sum(v * v for v in values) ** 0.5 or 1.0
    return [v / norm for v in values]


def index_products(db: Session, include_inactive: bool = False) -> int:
    settings = get_settings()
    ensure_product_collection()
    client = get_qdrant_client()
    stmt = select(Product)
    if not include_inactive:
        stmt = stmt.where(Product.is_active.is_(True))
    products = list(db.scalars(stmt))
    points = []
    for product in products:
        text = build_embedding_text(product)
        points.append(
            models.PointStruct(
                id=str(product.id),
                vector=deterministic_vector(text, settings.qdrant_vector_size),
                payload={
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
                    "is_group": product.is_group,
                    "is_active": product.is_active,
                    "embedding_text": text,
                },
            )
        )
    if points:
        client.upsert(collection_name=settings.qdrant_collection_products, points=points)
    return len(points)


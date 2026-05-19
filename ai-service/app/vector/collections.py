from qdrant_client.http import models

from app.core.config import get_settings
from app.vector.qdrant import get_qdrant_client


def ensure_product_collection() -> None:
    settings = get_settings()
    client = get_qdrant_client()
    collections = {c.name for c in client.get_collections().collections}
    if settings.qdrant_collection_products in collections:
        return
    client.create_collection(
        collection_name=settings.qdrant_collection_products,
        vectors_config=models.VectorParams(size=settings.qdrant_vector_size, distance=models.Distance.COSINE),
    )


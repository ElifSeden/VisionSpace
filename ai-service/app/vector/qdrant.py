from qdrant_client import QdrantClient

from app.core.config import get_settings


def get_qdrant_client() -> QdrantClient:
    return QdrantClient(url=get_settings().qdrant_url)


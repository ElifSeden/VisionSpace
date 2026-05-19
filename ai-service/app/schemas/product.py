from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.ai_outputs import ProductRetrievalIntent


class ProductImageOut(BaseModel):
    relative_path: str
    image_type: str
    is_primary: bool = False


class ProductOut(BaseModel):
    id: UUID
    external_id: str
    name: str
    category: str
    source_url: str | None = None
    image_path: str | None = None
    price: dict | None = None


class ProductCandidate(BaseModel):
    product_id: UUID
    external_id: str
    name: str
    category: str
    source_url: str | None = None
    image_path: str | None = None
    semantic_score: float = 0.0
    score: float = 0.0
    metadata: dict = Field(default_factory=dict)


class ProductSearchRequest(ProductRetrievalIntent):
    limit: int = 50


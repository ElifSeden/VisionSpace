from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    app_name: str = "ai-service"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    mock_ai: bool = False
    cors_allow_origins: list[str] = Field(default_factory=lambda: ["*"])

    database_url: str = "postgresql+psycopg://postgres:postgres@postgres:5432/furniture_ai"
    redis_url: str = "redis://redis:6379/0"

    qdrant_url: str = "http://qdrant:6333"
    qdrant_collection_products: str = "furniture_products"
    qdrant_text_vector_size: int = 768
    qdrant_image_vector_size: int = 1408

    vertex_project_id: str | None = None
    vertex_model_id: str = "gemini-3-flash-preview"
    vertex_pro_model_id: str = "gemini-3.1-pro-preview"
    vertex_location: str = "global"
    vertex_embedding_model: str = "text-embedding-005"
    vertex_multimodal_model: str = "multimodalembedding@001"
    vertex_multimodal_location: str = "us-central1"

    local_image_root: Path = Field(default=Path("/data/images"))
    product_image_dir: Path = Field(default=Path("/data/images/products"))
    room_upload_dir: Path = Field(default=Path("/data/images/rooms"))
    generated_image_dir: Path = Field(default=Path("/data/images/generated"))

    max_upload_mb: int = 15
    enable_image_generation: bool = False
    default_design_count: int = 3
    max_candidates_per_item: int = 50
    max_selected_per_design: int = 8


@lru_cache
def get_settings() -> Settings:
    return Settings()

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
    mock_ai: bool = True

    database_url: str = "postgresql+psycopg://postgres:postgres@postgres:5432/furniture_ai"
    redis_url: str = "redis://redis:6379/0"

    qdrant_url: str = "http://qdrant:6333"
    qdrant_collection_products: str = "furniture_products"
    qdrant_vector_size: int = 768

    gemini_api_key: str | None = None
    gemini_text_model: str = "gemini-2.5-flash"
    gemini_image_model: str = "gemini-2.5-flash-image"

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


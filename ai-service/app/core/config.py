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
    product_embedding_image_root: Path = Field(default=Path("/data/pipeline/output/images"))
    room_upload_dir: Path = Field(default=Path("/data/images/rooms"))
    generated_image_dir: Path = Field(default=Path("/data/images/generated"))

    max_upload_mb: int = 15
    debug_placement: bool = False
    enable_image_generation: bool = False
    default_design_count: int = 3
    max_candidates_per_item: int = 50
    max_selected_per_design: int = 8
    ignore_existing_furniture: bool = True
    remove_existing_furniture: bool = False

    # -- Sprint 2: Perspective-aware rendering ----------------------------
    # Furniture scale range — lower y (far) gets min_scale, higher y (close)
    # gets max_scale.  The linear formula is:
    #   scale = min + (normalized_y × (max − min))
    perspective_min_scale: float = 0.5
    perspective_max_scale: float = 1.5
    default_furniture_width: int = 400  # pixels at scale=1.0

    # Shadow rendering
    shadow_opacity: float = 0.45
    shadow_blur_radius: int = 15
    shadow_y_offset: int = 10

    # Optional perspective skew (disabled by default; can cause visual bugs)
    enable_perspective_skew: bool = False
    perspective_max_skew: float = 12.0  # max horizontal shift in pixels

    # -- Sprint 3: Rendering architecture ---------------------------------
    # Supported render methods:
    #   "overlay"       — Sprint 2 perspective PNG overlay (default, no GPU)
    #   "mock_inpaint"  — simulates SDXL pipeline (mask + prompt), renders via overlay
    #   "sdxl_inpaint"  — real SDXL + ControlNet (requires torch + diffusers + GPU)
    #   "external_ai"   — external API service (Replicate, Stability, Vertex Imagen)
    render_method: str = "overlay"

    # Mask generation for inpainting
    mask_dilation_px: int = 10  # dilate mask edges for better blending

    # -- Sprint 5: External AI inpainting provider -------------------------
    # Provider: "mock" | "replicate" | "huggingface" | "stability"
    external_ai_provider: str = "mock"
    external_ai_api_key: str | None = None  # loaded from env only, never hardcode
    external_ai_timeout_seconds: int = 120
    external_ai_max_retries: int = 2
    external_ai_image_size: int = 1024
    external_ai_save_payloads: bool = True  # save request payloads for debug
    external_ai_fallback_to_overlay: bool = True  # fall back on provider failure


@lru_cache
def get_settings() -> Settings:
    return Settings()

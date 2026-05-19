from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.room import RoomDimensions, UserPreferences


class CreateDesignJobRequest(BaseModel):
    room_image_path: str
    room_dimensions: RoomDimensions
    preferences: UserPreferences = Field(default_factory=UserPreferences)
    requested_design_count: int = 3


class CreateDesignJobResponse(BaseModel):
    job_id: UUID
    status: str


class UploadRoomImageResponse(BaseModel):
    image_path: str
    width: int
    height: int


class ProductCard(BaseModel):
    product_id: UUID
    external_id: str
    name: str
    category: str
    role: str | None = None
    source_url: str | None = None
    image_path: str | None = None
    price: dict | None = None
    reason: str | None = None
    score: float | None = None


class ClickableRegion(BaseModel):
    region_id: UUID
    type: str = "polygon"
    polygon: list[list[float]]
    product_id: UUID


class DesignOut(BaseModel):
    design_id: UUID
    title: str | None
    style: str | None
    summary: str | None
    image: dict | None = None
    clickable_regions: list[ClickableRegion] = Field(default_factory=list)
    products: list[ProductCard] = Field(default_factory=list)


class DesignJobOut(BaseModel):
    job_id: UUID
    status: str
    progress: dict | None = None
    error_message: str | None = None
    designs: list[DesignOut] = Field(default_factory=list)


from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class DetectedFurniture(BaseModel):
    label: str
    polygon: list[list[float]] = Field(default_factory=list)
    confidence: float = 0.0


class PlacementZone(BaseModel):
    label: str
    polygon: list[list[float]]
    notes: str | None = None


class RoomAnalysisResult(BaseModel):
    schema_version: str = "1.0"
    room_type: str
    detected_styles: list[str] = Field(default_factory=list)
    color_palette: list[str] = Field(default_factory=list)
    temperature: str | None = None
    lighting: str | None = None
    existing_furniture: list[DetectedFurniture] = Field(default_factory=list)
    available_placement_zones: list[PlacementZone] = Field(default_factory=list)
    constraints: dict = Field(default_factory=dict)
    confidence: float


class DesignStrategy(BaseModel):
    design_index: int
    title: str
    style: str | None = None
    furniture_roles: list[str]
    notes: str | None = None


class ProductRetrievalIntent(BaseModel):
    role: str
    category: str
    styles: list[str] = Field(default_factory=list)
    material: list[str] = Field(default_factory=list)
    colors: list[str] = Field(default_factory=list)
    temperature: str | None = None
    room_types: list[str] = Field(default_factory=list)
    max_width_cm: float | None = None
    max_depth_cm: float | None = None
    max_height_cm: float | None = None
    is_group_allowed: bool = True
    query_text: str


class ProductPlacement(BaseModel):
    product_id: UUID
    role: str
    placement_type: Literal["new", "replacement"] = "new"
    target_polygon: list[list[float]]
    depth_order: int = 0
    confidence: float
    notes: str | None = None


class PlacementPlan(BaseModel):
    placements: list[ProductPlacement]


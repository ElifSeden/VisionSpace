from typing import Any, Literal
from uuid import UUID

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator


class DetectedFurniture(BaseModel):
    model_config = ConfigDict(extra="ignore")

    label: str
    polygon: list[list[float]] = Field(default_factory=list)
    confidence: float = 0.0

    @field_validator("polygon", mode="before")
    @classmethod
    def _coerce_polygon(cls, v: Any) -> list[list[float]]:
        """Accept various polygon formats from AI and coerce to list[list[float]]."""
        if not isinstance(v, list):
            return []
        result = []
        for point in v:
            if isinstance(point, (list, tuple)) and len(point) >= 2:
                try:
                    result.append([float(point[0]), float(point[1])])
                except (ValueError, TypeError):
                    continue
        return result


class PlacementZone(BaseModel):
    model_config = ConfigDict(extra="ignore")

    label: str
    polygon: list[list[float]] = Field(default_factory=list)
    notes: str | None = None

    @field_validator("polygon", mode="before")
    @classmethod
    def _coerce_polygon(cls, v: Any) -> list[list[float]]:
        if not isinstance(v, list):
            return []
        result = []
        for point in v:
            if isinstance(point, (list, tuple)) and len(point) >= 2:
                try:
                    result.append([float(point[0]), float(point[1])])
                except (ValueError, TypeError):
                    continue
        return result


class RoomStyleProfile(BaseModel):
    """Structured style analysis of a room."""
    model_config = ConfigDict(extra="ignore")

    style: str = "unknown"
    confidence: float = 0.5
    dominant_colors: list[str] = Field(default_factory=list)
    materials: list[str] = Field(default_factory=list)
    room_type: str = "living_room"
    design_mood: str | None = None


class ArchitecturalContext(BaseModel):
    room_type: str = "living_room"
    floor_area: list[list[float]] = Field(default_factory=list)
    walls: list[dict] = Field(default_factory=list)
    windows: list[dict] = Field(default_factory=list)
    doors: list[dict] = Field(default_factory=list)
    lighting: str | None = None
    perspective: dict = Field(default_factory=dict)
    empty_room_style_hint: str | None = None


class RoomAnalysisResult(BaseModel):
    """Room analysis output from Gemini.

    Uses ``extra='ignore'`` so unexpected AI fields (e.g. ``architectural_context``)
    are silently dropped instead of crashing validation.
    """
    model_config = ConfigDict(extra="ignore")

    schema_version: str = "1.0"
    room_type: str = "living_room"
    detected_styles: list[str] = Field(default_factory=list)
    color_palette: list[str] = Field(default_factory=list)
    temperature: str | None = None
    lighting: str | None = None
    existing_furniture: list[DetectedFurniture] = Field(default_factory=list)
    existing_objects: list[DetectedFurniture] = Field(default_factory=list)
    architectural_context: ArchitecturalContext | None = None
    available_placement_zones: list[PlacementZone] = Field(default_factory=list)
    constraints: dict = Field(default_factory=dict)
    confidence: float = Field(
        default=0.5,
        validation_alias=AliasChoices('confidence', 'overall_confidence'),
    )
    style_profile: RoomStyleProfile | None = None

    @field_validator("existing_furniture", mode="before")
    @classmethod
    def _coerce_furniture(cls, v: Any) -> list:
        """Accept a list of dicts or silently drop malformed entries."""
        if not isinstance(v, list):
            return []
        result = []
        for item in v:
            if isinstance(item, dict):
                result.append(item)
            elif isinstance(item, str):
                # AI sometimes returns bare strings — wrap as a labelled item.
                result.append({"label": item, "polygon": [], "confidence": 0.3})
        return result

    @field_validator("available_placement_zones", mode="before")
    @classmethod
    def _coerce_zones(cls, v: Any) -> list:
        if not isinstance(v, list):
            return []
        result = []
        for item in v:
            if isinstance(item, dict):
                result.append(item)
            elif isinstance(item, str):
                result.append({"label": item, "polygon": []})
        return result

    @field_validator("constraints", mode="before")
    @classmethod
    def _coerce_constraints(cls, v: Any) -> dict:
        if isinstance(v, dict):
            return v
        if isinstance(v, list):
            return {"items": v}
        if isinstance(v, str):
            return {"note": v}
        return {}



class DesignStrategy(BaseModel):
    model_config = ConfigDict(extra="ignore")

    design_index: int
    title: str
    style: str | None = None
    furniture_roles: list[str] = Field(default_factory=list)
    notes: str | None = None

    @field_validator("furniture_roles", mode="before")
    @classmethod
    def _coerce_roles(cls, v: Any) -> list[str]:
        if isinstance(v, list):
            return [str(r) for r in v]
        if isinstance(v, str):
            return [v]
        return []


class ProductRetrievalIntent(BaseModel):
    role: str
    category: str
    styles: list[str] = Field(default_factory=list)
    material: list[str] = Field(default_factory=list)
    colors: list[str] = Field(default_factory=list)
    temperature: str | None = None
    room_types: list[str] = Field(default_factory=list)
    min_width_cm: float | None = None
    min_depth_cm: float | None = None
    min_height_cm: float | None = None
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

from typing import Literal

from pydantic import BaseModel, Field


class KnownReferenceObject(BaseModel):
    name: str
    width_cm: float | None = None
    height_cm: float | None = None
    polygon: list[list[float]] = Field(default_factory=list)


class RoomDimensions(BaseModel):
    unit: Literal["cm"]
    current_wall_length_cm: float | None = None
    room_depth_cm: float | None = None
    ceiling_height_cm: float | None = None
    known_reference_objects: list[KnownReferenceObject] = Field(default_factory=list)


class UserPreferences(BaseModel):
    mode: Literal["auto_design", "guided_design"] = "auto_design"
    replace_existing_furniture: bool = False
    requested_furniture_types: list[str] = Field(default_factory=list)
    replace_targets: list[str] = Field(default_factory=list)
    design_style: str | None = None
    material: str | None = None
    colors: list[str] = Field(default_factory=list)
    temperature: Literal["warm", "cold", "neutral"] | None = None
    size: str | None = None
    budget: dict | None = None
    extra_preferences: str | None = None


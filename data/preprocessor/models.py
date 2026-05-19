from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, field_validator


CATEGORY_TAXONOMY = {
    "sofa",
    "armchair",
    "chair",
    "dining_chair",
    "dining_table",
    "coffee_table",
    "side_table",
    "console_table",
    "tv_unit",
    "bed",
    "wardrobe",
    "dresser",
    "nightstand",
    "bookshelf",
    "desk",
    "office_chair",
    "lamp",
    "floor_lamp",
    "pendant_lamp",
    "rug",
    "curtain",
    "mirror",
    "wall_art",
    "plant_pot",
    "decoration",
    "storage_unit",
    "unknown",
}

STYLE_TAXONOMY = {
    "modern",
    "minimalist",
    "scandinavian",
    "industrial",
    "bohemian",
    "rustic",
    "luxury",
    "mid_century_modern",
    "traditional",
    "farmhouse",
    "contemporary",
    "japandi",
    "coastal",
    "classic",
    "art_deco",
    "unknown",
}

ROOM_TAXONOMY = {
    "living_room",
    "bedroom",
    "dining_room",
    "kitchen",
    "office",
    "hallway",
    "balcony",
    "bathroom",
    "kids_room",
    "outdoor",
    "unknown",
}

MATERIAL_TAXONOMY = {
    "wood",
    "metal",
    "glass",
    "marble",
    "stone",
    "plastic",
    "fabric",
    "leather",
    "velvet",
    "ceramic",
    "rattan",
    "bamboo",
    "mdf",
    "particle_board",
    "laminate",
    "acrylic",
    "unknown",
}

COLOR_TAXONOMY = {
    "white",
    "black",
    "gray",
    "beige",
    "cream",
    "brown",
    "warm_brown",
    "walnut_brown",
    "oak_brown",
    "dark_brown",
    "gold",
    "silver",
    "green",
    "blue",
    "navy",
    "red",
    "burgundy",
    "orange",
    "yellow",
    "pink",
    "purple",
    "transparent",
    "multicolor",
    "unknown",
}

TEMPERATURE_TAXONOMY = {"warm", "cool", "neutral", "unknown"}
VISUAL_WEIGHT_TAXONOMY = {"very_light", "light", "medium", "heavy", "very_heavy", "unknown"}
SPATIAL_FEEL_TAXONOMY = {"space_opening", "balanced", "space_filling", "bulky", "unknown"}
VERIFICATION_STATUS_TAXONOMY = {
    "high_confidence",
    "medium_confidence",
    "low_confidence",
    "unknown",
}
BRAND_TAXONOMY = {"vivense", "ikea", "istikbal", "unknown"}


def _clamp_confidence(value: Any) -> float:
    try:
        confidence = float(value)
    except (TypeError, ValueError):
        return 0.0
    return max(0.0, min(1.0, confidence))


def _taxonomy_value(value: Any, taxonomy: set[str], default: str = "unknown") -> str:
    if value is None:
        return default
    normalized = str(value).strip().lower().replace(" ", "_").replace("-", "_")
    return normalized if normalized in taxonomy else default


class ProductRaw(BaseModel):
    id: str = ""
    name: str = ""
    brand: str = "unknown"
    url: str = ""
    price: Optional[float] = None
    currency: str = "TRY"
    description: str = ""
    image_urls: List[str] = Field(default_factory=list)
    category: Optional[str] = None
    source_category: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    raw: Dict[str, Any] = Field(default_factory=dict)

    @field_validator("brand")
    @classmethod
    def normalize_brand(cls, value: str) -> str:
        return _taxonomy_value(value, BRAND_TAXONOMY)


class AttributeConfidence(BaseModel):
    name: str = "unknown"
    confidence: float = 0.0

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)


class CategoryAttribute(BaseModel):
    primary: str = "unknown"
    secondary: List[str] = Field(default_factory=list)
    confidence: float = 0.0

    @field_validator("primary")
    @classmethod
    def normalize_primary(cls, value: str) -> str:
        return _taxonomy_value(value, CATEGORY_TAXONOMY)

    @field_validator("secondary")
    @classmethod
    def normalize_secondary(cls, values: List[str]) -> List[str]:
        cleaned = [_taxonomy_value(value, CATEGORY_TAXONOMY) for value in values or []]
        return [value for value in cleaned if value != "unknown"]

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)


class StyleAttribute(AttributeConfidence):
    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        return _taxonomy_value(value, STYLE_TAXONOMY)


class RoomCompatibility(AttributeConfidence):
    room: str = "unknown"
    name: str = Field(default="unknown", exclude=True)

    @field_validator("room")
    @classmethod
    def normalize_room(cls, value: str) -> str:
        return _taxonomy_value(value, ROOM_TAXONOMY)


class ColorAttribute(BaseModel):
    name: str = "unknown"
    hex: str = "#000000"
    temperature: str = "unknown"
    confidence: float = 0.0

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        return _taxonomy_value(value, COLOR_TAXONOMY)

    @field_validator("hex", mode="before")
    @classmethod
    def normalize_hex(cls, value: Any) -> str:
        """Coerce None / empty hex strings (sometimes returned by the model) to the default."""
        if value is None or value == "":
            return "#000000"
        return str(value)

    @field_validator("temperature")
    @classmethod
    def normalize_temperature(cls, value: str) -> str:
        return _taxonomy_value(value, TEMPERATURE_TAXONOMY)

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)


class ColorAttributes(BaseModel):
    dominant: ColorAttribute = Field(default_factory=ColorAttribute)
    secondary: List[ColorAttribute] = Field(default_factory=list)


class MaterialAttribute(BaseModel):
    main: str = "unknown"
    subtype: str = "unknown"
    finish: str = "unknown"
    confidence: float = 0.0
    verification_status: str = "unknown"

    @field_validator("main")
    @classmethod
    def normalize_main(cls, value: str) -> str:
        return _taxonomy_value(value, MATERIAL_TAXONOMY)

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)

    @field_validator("verification_status")
    @classmethod
    def normalize_status(cls, value: str) -> str:
        return _taxonomy_value(value, VERIFICATION_STATUS_TAXONOMY)


class MaterialAttributes(BaseModel):
    dominant: MaterialAttribute = Field(default_factory=MaterialAttribute)
    secondary: List[MaterialAttribute] = Field(default_factory=list)


class DimensionsCm(BaseModel):
    width: Optional[float] = None
    depth: Optional[float] = None
    height: Optional[float] = None
    confidence: float = 0.0

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)


class ShapeAttribute(BaseModel):
    main: str = "unknown"
    edge_style: str = "unknown"
    shape_language: str = "unknown"
    confidence: float = 0.0

    @field_validator("confidence")
    @classmethod
    def confidence_range(cls, value: Any) -> float:
        return _clamp_confidence(value)


class FurnitureAttributes(BaseModel):
    category: CategoryAttribute = Field(default_factory=CategoryAttribute)
    styles: List[StyleAttribute] = Field(default_factory=lambda: [StyleAttribute()])
    colors: ColorAttributes = Field(default_factory=ColorAttributes)
    materials: MaterialAttributes = Field(default_factory=MaterialAttributes)
    dimensions_cm: DimensionsCm = Field(default_factory=DimensionsCm)
    room_compatibility: List[RoomCompatibility] = Field(default_factory=lambda: [RoomCompatibility()])
    shape: ShapeAttribute = Field(default_factory=ShapeAttribute)
    visual_features: List[str] = Field(default_factory=list)
    design_tags: List[str] = Field(default_factory=list)
    spatial_feel: str = "unknown"
    visual_weight: str = "unknown"
    texture_intensity: str = "unknown"
    contrast_level: str = "unknown"
    usage_intent: List[str] = Field(default_factory=list)
    quality_tier: str = "unknown"
    assembly_required: str = "unknown"

    @field_validator("styles")
    @classmethod
    def ensure_styles(cls, values: List[StyleAttribute]) -> List[StyleAttribute]:
        return values or [StyleAttribute()]

    @field_validator("room_compatibility")
    @classmethod
    def ensure_rooms(cls, values: List[RoomCompatibility]) -> List[RoomCompatibility]:
        return values or [RoomCompatibility()]

    @field_validator("spatial_feel")
    @classmethod
    def normalize_spatial_feel(cls, value: str) -> str:
        return _taxonomy_value(value, SPATIAL_FEEL_TAXONOMY)

    @field_validator("visual_weight")
    @classmethod
    def normalize_visual_weight(cls, value: str) -> str:
        return _taxonomy_value(value, VISUAL_WEIGHT_TAXONOMY)


class SemanticText(BaseModel):
    aesthetic_caption: str = ""
    functional_caption: str = ""
    material_caption: str = ""
    attribute_caption: str = ""


class EmbeddingMetadata(BaseModel):
    image_model: str = "clip_or_siglip"
    text_model: str = "text_embedding_model"
    caption_prompt_version: str = "v1"
    attribute_schema_version: str = "v1"
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class LatentCluster(BaseModel):
    id: Optional[str] = None
    label: Optional[str] = None


class EnrichedProduct(BaseModel):
    id: str
    name: str
    brand: str = "unknown"
    url: str = ""
    price: Optional[float] = None
    currency: str = "TRY"
    description: str = ""
    image_urls: List[str] = Field(default_factory=list)
    attributes: FurnitureAttributes = Field(default_factory=FurnitureAttributes)
    semantic_text: SemanticText = Field(default_factory=SemanticText)
    embedding_metadata: EmbeddingMetadata = Field(default_factory=EmbeddingMetadata)
    latent_cluster: LatentCluster = Field(default_factory=LatentCluster)

    @field_validator("brand")
    @classmethod
    def normalize_brand(cls, value: str) -> str:
        return _taxonomy_value(value, BRAND_TAXONOMY)

class ProductSpecs(BaseModel):
    material: str
    leg_type: str

class Dimensions(BaseModel):
    w: int
    d: int
    h: int

class ProductMetadata(BaseModel):
    specs: ProductSpecs
    dimensions: Dimensions
    # Keeping original necessary fields
    product_id: str = ""
    name: str = ""
    price_try: float = 0.0
    image_url: str = ""

class DesignDNA(BaseModel):
    visual_weight: float
    texture: str
    primary_form: str
    is_focal_point: bool = False

class FurnitureItem(BaseModel):
    product_metadata: ProductMetadata
    design_dna: DesignDNA

from pydantic import BaseModel, Field
from typing import List, Optional

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

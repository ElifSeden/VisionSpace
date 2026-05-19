from typing import List

from pydantic import BaseModel, Field

from preprocessor.vertex_ai import VertexAIClient, file_part_from_path, parse_json_object


class FurnitureAttributes(BaseModel):
    category: str = Field(description="E.g., 'Sehpa', 'Koltuk', 'Yatak', 'Masa'")
    room_type: List[str] = Field(description="E.g., ['living_room'], ['bedroom'], ['dining_room']")
    main_color: str = Field(description="The dominant color of the furniture")
    secondary_colors: List[str] = Field(description="Any side colors visible")
    material: List[str] = Field(description="E.g., ['wood'], ['metal'], ['fabric'], ['leather']")
    style: List[str] = Field(description="E.g., ['modern'], ['japandi'], ['minimalist'], ['bohemian'], ['scandinavian']")
    temperature: str = Field(description="Must be one of: 'warm', 'cold', 'neutral'")
    dimensions: str = Field(description="Extract dimensions if mentioned in text, otherwise 'unknown'")
    availability: str = Field(description="Default to 'in_stock' unless metadata says otherwise")
    visual_tags: List[str] = Field(description="3 to 5 descriptive visual tags")


class DesignLabeler:
    def __init__(self):
        self.client = VertexAIClient()

    def analyze_furniture(self, image_path: str, raw_data: dict) -> FurnitureAttributes:
        prompt = f"""
You are an expert interior designer and computer vision agent.
Analyze the provided furniture image and scraped metadata to enrich the database.
Return ONLY valid JSON matching this exact schema:
{{
  "category": "",
  "room_type": [],
  "main_color": "",
  "secondary_colors": [],
  "material": [],
  "style": [],
  "temperature": "warm|cold|neutral",
  "dimensions": "",
  "availability": "",
  "visual_tags": []
}}

Product Name: {raw_data.get('name', '')}
Product Description: {raw_data.get('description', '')}
If a field cannot be inferred from image or text, use "unknown".
""".strip()
        parts = []
        image_part = file_part_from_path(image_path) if image_path else None
        if image_part:
            parts.append(image_part)
        parts.append({"text": prompt})

        response_text = self.client.stream_generate_content(
            parts=parts,
            temperature=0.2,
            response_mime_type="application/json",
        )
        return FurnitureAttributes.model_validate(parse_json_object(response_text))

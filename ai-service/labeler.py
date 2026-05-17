import os
from google import genai
from PIL import Image
from models import FurnitureItem

class DesignLabeler:
    def __init__(self, api_key: str):
        self.client = genai.Client(api_key=api_key)

    def analyze_furniture(self, image_path: str, raw_data: dict) -> FurnitureItem:
        prompt = f"""
        Analyze this furniture image and metadata: {raw_data.get('description', '')}
        Return a JSON object matching this schema:
        - visual_weight: 1-10 (1=glass/thin legs, 10=dark/bulky/touches floor)
        - color_profile: Warm, Cool, Neutral, or High-Chroma
        - material_texture: Reflective, Rough, Soft, Matte, or Organic
        - style_cluster: Minimalist, Scandi, Industrial, Bohemian, or Mid-Century
        - is_focal_point: boolean (True if it's a unique statement piece)
        """
        
        # Pass the image path as a PIL image if it exists and is a local file path
        if image_path and os.path.exists(image_path):
             image = Image.open(image_path)
             contents = [prompt, image]
        else:
             contents = [prompt]
             
        response = self.client.models.generate_content(
             model='gemini-2.5-flash',
             contents=contents,
        )
        return FurnitureItem.model_validate_json(response.text)

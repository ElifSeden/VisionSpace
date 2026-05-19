import json
import re
from typing import Any


def extract_json_object(text: str) -> Any:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?", "", cleaned).removesuffix("```").strip()
    return json.loads(cleaned)


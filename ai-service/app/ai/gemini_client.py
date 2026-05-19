from pathlib import Path
from typing import TypeVar

from google import genai
from pydantic import BaseModel, ValidationError
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import Settings, get_settings
from app.core.errors import AIOutputValidationError
from app.utils.json_utils import extract_json_object

T = TypeVar("T", bound=BaseModel)


class GeminiClient:
    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()
        self.client = genai.Client(api_key=self.settings.gemini_api_key) if self.settings.gemini_api_key else None

    @retry(wait=wait_exponential(multiplier=1, min=1, max=8), stop=stop_after_attempt(3))
    def generate_json(self, prompt: str, response_schema: type[T], images: list[Path] | None = None) -> T:
        if self.settings.mock_ai or not self.client:
            raise AIOutputValidationError("Gemini is not configured; use workflow mock nodes")

        parts: list = [prompt]
        for image_path in images or []:
            parts.append(self.client.files.upload(file=image_path))

        response = self.client.models.generate_content(
            model=self.settings.gemini_text_model,
            contents=parts,
            config={"response_mime_type": "application/json"},
        )
        try:
            return response_schema.model_validate(extract_json_object(response.text or "{}"))
        except ValidationError as exc:
            raise AIOutputValidationError(str(exc)) from exc

    def generate_image_edit(self, prompt: str, images: list[Path], output_path: Path) -> Path:
        raise NotImplementedError("Gemini image editing is intentionally gated behind ENABLE_IMAGE_GENERATION")


def load_prompt(name: str) -> str:
    return (Path(__file__).parent / "prompts" / name).read_text(encoding="utf-8")


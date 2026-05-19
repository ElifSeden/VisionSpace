import base64
import json
import mimetypes
from pathlib import Path
from typing import Any, TypeVar

import requests
from google.auth import default
from google.auth.transport.requests import Request
from pydantic import BaseModel, ValidationError
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import Settings, get_settings
from app.core.errors import AIOutputValidationError
from app.utils.json_utils import extract_json_object

T = TypeVar("T", bound=BaseModel)

_VERTEX_SCOPE = "https://www.googleapis.com/auth/cloud-platform"


class VertexAIClient:
    """Vertex AI REST client using Application Default Credentials."""

    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()
        self._credentials = None

    @property
    def project_id(self) -> str | None:
        return self.settings.vertex_project_id

    @property
    def location(self) -> str:
        return self.settings.vertex_location

    def _resolve_model(self, model_tier: str = "flash") -> str:
        if model_tier == "pro":
            return self.settings.vertex_pro_model_id
        return self.settings.vertex_model_id

    def _generate_endpoint(self, model_tier: str = "flash") -> str:
        model = self._resolve_model(model_tier)
        return (
            "https://aiplatform.googleapis.com/v1/"
            f"projects/{self.project_id}/locations/{self.location}/"
            f"publishers/google/models/{model}:streamGenerateContent"
        )

    @property
    def embedding_endpoint(self) -> str:
        return (
            "https://aiplatform.googleapis.com/v1/"
            f"projects/{self.project_id}/locations/{self.location}/"
            f"publishers/google/models/{self.settings.vertex_embedding_model}:predict"
        )

    def _access_token(self) -> str:
        if self._credentials is None:
            self._credentials, _ = default(scopes=[_VERTEX_SCOPE])
        self._credentials.refresh(Request())
        if not self._credentials.token:
            raise AIOutputValidationError("Could not obtain Google ADC access token")
        return self._credentials.token

    def _auth_headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self._access_token()}",
            "Content-Type": "application/json",
        }

    def _stream_generate(
        self,
        parts: list[dict[str, Any]],
        temperature: float = 0.2,
        response_mime_type: str | None = None,
        model_tier: str = "flash",
    ) -> str:
        generation_config: dict[str, Any] = {"temperature": temperature}
        if response_mime_type:
            generation_config["responseMimeType"] = response_mime_type

        payload: dict[str, Any] = {
            "contents": {"role": "user", "parts": parts},
            "generationConfig": generation_config,
        }
        endpoint = self._generate_endpoint(model_tier)
        response = requests.post(
            endpoint,
            headers=self._auth_headers(),
            json=payload,
            timeout=180,
        )
        if response.status_code >= 400:
            raise AIOutputValidationError(
                f"Vertex AI request failed ({response.status_code}): {response.text}"
            )
        return _extract_text_from_stream(response.text)

    @retry(wait=wait_exponential(multiplier=1, min=1, max=8), stop=stop_after_attempt(3))
    def generate_json(
        self,
        prompt: str,
        response_schema: type[T],
        images: list[Path] | None = None,
        model_tier: str = "flash",
    ) -> T:
        if self.settings.mock_ai or not self.project_id:
            raise AIOutputValidationError("Vertex AI is not configured; use workflow mock nodes")

        parts: list[dict[str, Any]] = [{"text": prompt}]
        for image_path in images or []:
            part = _file_part(image_path)
            if part:
                parts.append(part)

        text = self._stream_generate(
            parts, temperature=0.2, response_mime_type="application/json", model_tier=model_tier
        )
        try:
            return response_schema.model_validate(extract_json_object(text))
        except ValidationError as exc:
            import structlog
            _log = structlog.get_logger("vertex_client")
            _log.warning(
                "ai_output_validation_failed",
                schema=response_schema.__name__,
                raw_text=text[:2000],
                error=str(exc)[:500],
            )
            raise AIOutputValidationError(str(exc)) from exc

    @retry(wait=wait_exponential(multiplier=2, min=2, max=30), stop=stop_after_attempt(5))
    def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Embed a batch of texts using Vertex AI embedding model."""
        if not self.project_id:
            raise AIOutputValidationError("VERTEX_PROJECT_ID is required for embeddings")

        instances = [{"content": t} for t in texts]
        payload = {"instances": instances}
        response = requests.post(
            self.embedding_endpoint,
            headers=self._auth_headers(),
            json=payload,
            timeout=120,
        )
        if response.status_code >= 400:
            raise AIOutputValidationError(
                f"Vertex embedding failed ({response.status_code}): {response.text}"
            )
        data = response.json()
        return [pred["embeddings"]["values"] for pred in data.get("predictions", [])]

    @property
    def multimodal_endpoint(self) -> str:
        loc = self.settings.vertex_multimodal_location
        return (
            f"https://{loc}-aiplatform.googleapis.com/v1/"
            f"projects/{self.project_id}/locations/{loc}/"
            f"publishers/google/models/{self.settings.vertex_multimodal_model}:predict"
        )

    @retry(wait=wait_exponential(multiplier=2, min=2, max=30), stop=stop_after_attempt(5))
    def embed_multimodal(
        self,
        text: str | None = None,
        image_bytes: bytes | None = None,
        dimension: int = 1408,
    ) -> list[float]:
        """Embed text and/or image using the multimodal embedding model.

        Returns a single vector in the shared text-image embedding space.
        Accepts text-only, image-only, or both. When both are provided the
        model produces a fused vector that captures both modalities.
        """
        if not self.project_id:
            raise AIOutputValidationError("VERTEX_PROJECT_ID is required for embeddings")

        instance: dict[str, Any] = {}
        if text:
            instance["text"] = text
        if image_bytes:
            instance["image"] = {
                "bytesBase64Encoded": base64.b64encode(image_bytes).decode("ascii"),
            }
        if not instance:
            raise AIOutputValidationError("embed_multimodal requires text and/or image_bytes")

        payload: dict[str, Any] = {
            "instances": [instance],
            "parameters": {"dimension": dimension},
        }
        response = requests.post(
            self.multimodal_endpoint,
            headers=self._auth_headers(),
            json=payload,
            timeout=120,
        )
        if response.status_code >= 400:
            raise AIOutputValidationError(
                f"Multimodal embedding failed ({response.status_code}): {response.text}"
            )
        data = response.json()
        pred = data.get("predictions", [{}])[0]
        # The model returns textEmbedding and/or imageEmbedding depending on input
        return (
            pred.get("imageEmbedding")
            or pred.get("textEmbedding")
            or pred.get("embedding", [])
        )

    def generate_image_edit(self, prompt: str, images: list[Path], output_path: Path) -> Path:
        raise NotImplementedError(
            "Image editing is intentionally gated behind ENABLE_IMAGE_GENERATION"
        )


def _file_part(path: Path) -> dict[str, Any] | None:
    if not path.exists() or not path.is_file():
        return None
    mime_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return {"inlineData": {"mimeType": mime_type, "data": data}}


def _extract_text_from_stream(raw_text: str) -> str:
    raw_text = raw_text.strip()
    if not raw_text:
        return ""

    try:
        payload = json.loads(raw_text)
        chunks = payload if isinstance(payload, list) else [payload]
    except json.JSONDecodeError:
        chunks = []
        for line in raw_text.splitlines():
            line = line.strip()
            if not line or line == ",":
                continue
            if line.startswith("data:"):
                line = line[5:].strip()
            line = line.strip(",")
            if not line or line in {"[", "]"}:
                continue
            try:
                chunks.append(json.loads(line))
            except json.JSONDecodeError:
                continue
        if not chunks:
            return raw_text

    parts: list[str] = []
    for chunk in chunks:
        for candidate in chunk.get("candidates", []) if isinstance(chunk, dict) else []:
            content = candidate.get("content") or {}
            for part in content.get("parts", []):
                text = part.get("text")
                if text:
                    parts.append(text)
    return "".join(parts).strip()


def load_prompt(name: str) -> str:
    return (Path(__file__).parent / "prompts" / name).read_text(encoding="utf-8")

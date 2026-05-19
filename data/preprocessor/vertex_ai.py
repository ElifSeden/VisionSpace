import base64
import json
import mimetypes
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from google.auth import default
from google.auth.transport.requests import Request


DEFAULT_LOCATION = "global"
DEFAULT_MODEL_ID = "gemini-3-flash-preview"
_VERTEX_SCOPE = "https://www.googleapis.com/auth/cloud-platform"


class VertexAIError(RuntimeError):
    pass


def _env(name: str, fallback: Optional[str] = None) -> Optional[str]:
    value = os.getenv(name)
    return value if value not in (None, "") else fallback


class VertexAIClient:
    def __init__(
        self,
        project_id: Optional[str] = None,
        model_id: Optional[str] = None,
        location: Optional[str] = None,
    ):
        self.project_id = _env("PROJECT_ID", project_id)
        self.model_id = _env("MODEL_ID", model_id) or DEFAULT_MODEL_ID
        self.location = _env("VERTEX_LOCATION", location) or DEFAULT_LOCATION
        if not self.project_id:
            raise VertexAIError("PROJECT_ID is required for Vertex AI calls")

    @property
    def endpoint(self) -> str:
        return (
            "https://aiplatform.googleapis.com/v1/"
            f"projects/{self.project_id}/locations/{self.location}/"
            f"publishers/google/models/{self.model_id}:streamGenerateContent"
        )

    def _access_token(self) -> str:
        credentials, _ = default(scopes=[_VERTEX_SCOPE])
        credentials.refresh(Request())
        if not credentials.token:
            raise VertexAIError("Could not obtain Google application default access token")
        return credentials.token

    def stream_generate_content(
        self,
        parts: List[Dict[str, Any]],
        temperature: float = 0.2,
        response_mime_type: Optional[str] = None,
    ) -> str:
        generation_config: Dict[str, Any] = {"temperature": temperature}
        if response_mime_type:
            generation_config["responseMimeType"] = response_mime_type

        payload: Dict[str, Any] = {
            "contents": {
                "role": "user",
                "parts": parts,
            },
            "generationConfig": generation_config,
        }
        response = requests.post(
            self.endpoint,
            headers={
                "Authorization": f"Bearer {self._access_token()}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=120,
        )
        if response.status_code >= 400:
            raise VertexAIError(f"Vertex AI request failed ({response.status_code}): {response.text}")
        return extract_text_from_stream_response(response.text)

    def generate_json(self, prompt: str, temperature: float = 0.2) -> Dict[str, Any]:
        text = self.stream_generate_content(
            parts=[{"text": prompt}],
            temperature=temperature,
            response_mime_type="application/json",
        )
        return parse_json_object(text)


def file_part_from_path(path_value: str) -> Optional[Dict[str, Any]]:
    if not path_value:
        return None
    if path_value.startswith("gs://"):
        mime_type = mimetypes.guess_type(path_value)[0] or "application/octet-stream"
        return {"fileData": {"mimeType": mime_type, "fileUri": path_value}}

    path = Path(path_value)
    if not path.exists() or not path.is_file():
        return None

    mime_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return {"inlineData": {"mimeType": mime_type, "data": data}}


def extract_text_from_stream_response(raw_text: str) -> str:
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

    parts: List[str] = []
    for chunk in chunks:
        for candidate in chunk.get("candidates", []) if isinstance(chunk, dict) else []:
            content = candidate.get("content") or {}
            for part in content.get("parts", []):
                text = part.get("text")
                if text:
                    parts.append(text)
    return "".join(parts).strip()


def parse_json_object(text: str) -> Dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        text = text.removeprefix("```json").removeprefix("```").strip()
        if text.endswith("```"):
            text = text[:-3].strip()
    parsed = json.loads(text)
    # The streamGenerateContent endpoint sometimes wraps the object in a JSON
    # array. Unwrap single-element arrays so callers always receive a dict.
    if isinstance(parsed, list):
        if len(parsed) == 1 and isinstance(parsed[0], dict):
            return parsed[0]
        raise ValueError(
            f"Expected a JSON object from Vertex AI but got a {len(parsed)}-element array"
        )
    return parsed

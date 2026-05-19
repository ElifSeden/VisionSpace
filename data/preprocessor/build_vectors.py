import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

import numpy as np

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    load_dotenv = None

try:
    from tqdm import tqdm
except ImportError:  # pragma: no cover
    tqdm = None


SCRIPT_DIR = Path(__file__).resolve().parent
PLACEHOLDER_DIM = int(os.getenv("PLACEHOLDER_VECTOR_DIM", "384"))


def load_env() -> None:
    if load_dotenv:
        load_dotenv(SCRIPT_DIR / ".env")
        load_dotenv(SCRIPT_DIR.parent / ".env")


def resolve_input_path(path_value: str) -> Path:
    candidate = Path(path_value).expanduser()
    if candidate.exists():
        return candidate
    for base in (SCRIPT_DIR, SCRIPT_DIR / "output", SCRIPT_DIR.parent, SCRIPT_DIR.parent / "output", SCRIPT_DIR.parent.parent):
        candidate = base / path_value
        if candidate.exists():
            return candidate
    return Path(path_value)


def iter_jsonl(path: Path) -> Iterable[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                yield json.loads(line)


def semantic_text_for_embedding(product: Dict[str, Any]) -> str:
    semantic = product.get("semantic_text") or {}
    parts = [
        semantic.get("aesthetic_caption", ""),
        semantic.get("functional_caption", ""),
        semantic.get("material_caption", ""),
        semantic.get("attribute_caption", ""),
    ]
    return " ".join(part.strip() for part in parts if part and part.strip())


def deterministic_placeholder_vector(text: str, dim: int = PLACEHOLDER_DIM) -> List[float]:
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    seed = int.from_bytes(digest[:8], "big", signed=False)
    rng = np.random.default_rng(seed)
    vector = rng.normal(0, 1, dim).astype(np.float32)
    norm = float(np.linalg.norm(vector))
    if norm > 0:
        vector = vector / norm
    return vector.tolist()


class EmbeddingProvider:
    model_name = "deterministic_placeholder"

    def embed(self, text: str) -> List[float]:
        return deterministic_placeholder_vector(text)


def get_embedding_provider() -> EmbeddingProvider:
    print("Using deterministic placeholder vectors. Vertex generation is configured separately for enrichment.")
    return EmbeddingProvider()


def enrich_with_vectors(input_path: Path, output_path: Path, limit: Optional[int]) -> None:
    provider = get_embedding_provider()
    rows = list(iter_jsonl(input_path))
    if limit is not None:
        rows = rows[:limit]

    iterator = tqdm(rows, desc="embedding") if tqdm else rows
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8") as out:
        for product in iterator:
            text = semantic_text_for_embedding(product) or f"{product.get('name', '')} {product.get('description', '')}"
            product.setdefault("vectors", {})
            product["vectors"]["semantic_vector"] = provider.embed(text)
            product.setdefault("embedding_metadata", {})
            product["embedding_metadata"]["text_model"] = provider.model_name
            out.write(json.dumps(product, ensure_ascii=False) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build semantic vectors for enriched furniture products.")
    parser.add_argument("--input", default="enriched_products.jsonl", help="Input enriched JSONL path.")
    parser.add_argument("--output", default="enriched_with_vectors.jsonl", help="Output JSONL path.")
    parser.add_argument("--limit", type=int, default=None, help="Optional max products to process.")
    return parser.parse_args()


def main() -> None:
    load_env()
    args = parse_args()
    input_path = resolve_input_path(args.input)
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")
    enrich_with_vectors(input_path, Path(args.output), args.limit)


if __name__ == "__main__":
    main()

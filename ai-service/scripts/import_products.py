import json
import sys
from pathlib import Path

from pydantic import BaseModel, Field, ValidationError

from app.db.repositories.product_repository import ProductRepository
from app.db.session import new_session


class ImportProduct(BaseModel):
    external_id: str
    name: str
    category: str
    source: str | None = None
    source_url: str | None = None
    description: str | None = None
    price: dict = Field(default_factory=dict)
    dimensions: dict = Field(default_factory=dict)
    material: list[str] = Field(default_factory=list)
    colors: list[str] = Field(default_factory=list)
    styles: list[str] = Field(default_factory=list)
    temperature: str | None = None
    room_types: list[str] = Field(default_factory=list)
    is_group: bool = False
    group_items: list | dict = Field(default_factory=list)
    images: list[dict] = Field(default_factory=list)
    raw_metadata: dict = Field(default_factory=dict)
    enriched_metadata: dict = Field(default_factory=dict)
    metadata_confidence: dict = Field(default_factory=dict)
    is_active: bool = True


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/import_products.py path/to/products.json")
    path = Path(sys.argv[1])
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise SystemExit("Import file must contain a JSON array")

    imported = 0
    errors = []
    with new_session() as db:
        repo = ProductRepository(db)
        for index, item in enumerate(payload):
            try:
                product_data = ImportProduct.model_validate(item).model_dump()
                product = repo.upsert_product(product_data)
                repo.upsert_images(product, product_data.get("images", []))
                imported += 1
            except (ValidationError, KeyError) as exc:
                errors.append({"index": index, "error": str(exc)})
        db.commit()

    print(json.dumps({"imported": imported, "errors": errors}, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

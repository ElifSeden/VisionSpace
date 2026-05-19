"""Import enriched_products.jsonl (preprocessor output) into the products database.

Usage:
    python scripts/import_enriched.py path/to/enriched_products.jsonl
"""
import json
import sys
from pathlib import Path

from app.db.repositories.product_repository import ProductRepository
from app.db.session import new_session


def map_enriched_to_db(record: dict) -> dict:
    """Map an enriched product JSONL record to the Product DB shape."""
    attrs = record.get("attributes") or {}
    category_obj = attrs.get("category") or {}
    colors_obj = attrs.get("colors") or {}
    materials_obj = attrs.get("materials") or {}
    dimensions_obj = attrs.get("dimensions_cm") or {}

    # Flatten styles
    styles = [s["name"] for s in attrs.get("styles", []) if s.get("name") and s["name"] != "unknown"]

    # Flatten colors: dominant + secondary names
    all_colors = []
    dominant_color = colors_obj.get("dominant", {})
    if dominant_color.get("name") and dominant_color["name"] != "unknown":
        all_colors.append(dominant_color["name"])
    for sec in colors_obj.get("secondary", []):
        if sec.get("name") and sec["name"] != "unknown" and sec["name"] not in all_colors:
            all_colors.append(sec["name"])

    # Flatten materials: dominant + secondary main
    all_materials = []
    dominant_mat = materials_obj.get("dominant", {})
    if dominant_mat.get("main") and dominant_mat["main"] != "unknown":
        all_materials.append(dominant_mat["main"])
    for sec in materials_obj.get("secondary", []):
        if sec.get("main") and sec["main"] != "unknown" and sec["main"] not in all_materials:
            all_materials.append(sec["main"])

    # Temperature from dominant color
    temperature = dominant_color.get("temperature")
    if temperature == "unknown":
        temperature = None

    # Room types
    room_types = [
        r["room"] for r in attrs.get("room_compatibility", [])
        if r.get("room") and r["room"] != "unknown"
    ]

    # Prefer crawler-downloaded local image paths. Remote URLs are retained only
    # as a fallback for older records that do not include local image metadata.
    local_image_sources = record.get("local_image_paths") or record.get("image_paths")
    image_sources = local_image_sources or record.get("image_urls") or []
    image_type = "local" if local_image_sources else "remote"
    images = []
    seen_images = set()
    for source in image_sources:
        if not source or source in seen_images:
            continue
        seen_images.add(source)
        images.append({
            "relative_path": source,
            "image_type": image_type,
            "is_primary": len(images) == 0,
            "sort_order": len(images),
        })

    # Build confidence map
    confidence = {
        "category": category_obj.get("confidence"),
        "dimensions": dimensions_obj.get("confidence"),
        "dominant_color": dominant_color.get("confidence"),
        "dominant_material": dominant_mat.get("confidence"),
    }

    return {
        "external_id": record["id"],
        "name": record.get("name", ""),
        "description": record.get("description", ""),
        "category": category_obj.get("primary", "unknown"),
        "source": record.get("brand"),
        "source_url": record.get("url"),
        "price": {
            "amount": record.get("price"),
            "currency": record.get("currency", "TRY"),
        },
        "dimensions": {
            "width_cm": dimensions_obj.get("width"),
            "depth_cm": dimensions_obj.get("depth"),
            "height_cm": dimensions_obj.get("height"),
        },
        "material": all_materials,
        "colors": all_colors,
        "styles": styles,
        "temperature": temperature,
        "room_types": room_types,
        "is_group": len(category_obj.get("secondary", [])) > 0,
        "group_items": category_obj.get("secondary", []),
        "images": images,
        "raw_metadata": {},
        "enriched_metadata": attrs,
        "metadata_confidence": confidence,
        "semantic_text": record.get("semantic_text"),
        "shape": attrs.get("shape"),
        "visual_features": attrs.get("visual_features", []),
        "design_tags": attrs.get("design_tags", []),
        "visual_weight": attrs.get("visual_weight"),
        "spatial_feel": attrs.get("spatial_feel"),
        "usage_intent": attrs.get("usage_intent", []),
        "quality_tier": attrs.get("quality_tier"),
        "is_active": True,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/import_enriched.py path/to/enriched_products.jsonl")

    path = Path(sys.argv[1])
    if not path.exists():
        raise SystemExit(f"File not found: {path}")

    imported = 0
    errors = []

    with new_session() as db:
        repo = ProductRepository(db)
        with path.open("r", encoding="utf-8") as f:
            for line_number, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                    product_data = map_enriched_to_db(record)
                    product = repo.upsert_product(product_data)
                    repo.upsert_images(product, product_data.get("images", []))
                    imported += 1
                except Exception as exc:
                    errors.append({"line": line_number, "error": str(exc)})
        db.commit()

    print(json.dumps({"imported": imported, "errors": errors}, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

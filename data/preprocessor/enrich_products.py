import argparse
import hashlib
import threading
from concurrent.futures import ThreadPoolExecutor
import json
import os
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse


if __package__ in (None, ""):
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - fallback for minimal local runs
    load_dotenv = None

try:
    from tqdm import tqdm
except ImportError:  # pragma: no cover
    tqdm = None

from preprocessor.vertex_ai import VertexAIClient
from preprocessor.models import (
    COLOR_TAXONOMY,
    MATERIAL_TAXONOMY,
    ROOM_TAXONOMY,
    STYLE_TAXONOMY,
    CategoryAttribute,
    ColorAttribute,
    ColorAttributes,
    DimensionsCm,
    EmbeddingMetadata,
    EnrichedProduct,
    FurnitureAttributes,
    LatentCluster,
    MaterialAttribute,
    MaterialAttributes,
    ProductRaw,
    RoomCompatibility,
    SemanticText,
    ShapeAttribute,
    StyleAttribute,
)


SCRIPT_DIR = Path(__file__).resolve().parent
_THREAD_LOCAL = threading.local()

COLOR_HEX = {
    "white": "#FFFFFF",
    "black": "#111111",
    "gray": "#808080",
    "beige": "#D6C2A8",
    "cream": "#F5E6C8",
    "brown": "#7A5230",
    "warm_brown": "#6B4F3A",
    "walnut_brown": "#5C4033",
    "oak_brown": "#B88746",
    "dark_brown": "#3B2416",
    "gold": "#C9A227",
    "silver": "#C0C0C0",
    "green": "#2F6B4F",
    "blue": "#3366AA",
    "navy": "#0B1F3A",
    "red": "#B3261E",
    "burgundy": "#7A1E2C",
    "orange": "#D97324",
    "yellow": "#E3B341",
    "pink": "#D8839A",
    "purple": "#6F4E9B",
    "transparent": "#FFFFFF",
    "multicolor": "#999999",
    "unknown": "#000000",
}


CATEGORY_KEYWORDS = [
    ("coffee_table", ("sehpa", "orta sehpa", "coffee table", "z وال", "z sehpa")),
    ("side_table", ("yan sehpa", "side table", "komodin sehpa")),
    ("console_table", ("konsol", "console")),
    ("tv_unit", ("tv", "televizyon", "ünite", "unite")),
    ("dining_table", ("yemek masası", "yemek masasi", "yemek odası", "yemek odasi", "dining table", "masa takımı", "masa takimi")),
    ("dining_chair", ("yemek sandalyesi", "dining chair")),
    ("office_chair", ("ofis sandalyesi", "çalışma sandalyesi", "office chair")),
    ("armchair", ("berjer", "tekli koltuk", "armchair")),
    ("sofa", ("koltuk", "kanepe", "sofa", "corner", "köşe")),
    ("chair", ("sandalye", "chair")),
    ("bed", ("yatak", "karyola", "başlık", "baslik", "headboard", "bed")),
    ("wardrobe", ("gardırop", "gardrop", "wardrobe", "dolap")),
    ("dresser", ("şifonyer", "sifonyer", "makyaj masası", "makyaj masasi", "dresser")),
    ("nightstand", ("komodin", "nightstand")),
    ("bookshelf", ("kitaplık", "bookshelf")),
    ("desk", ("çalışma masası", "desk")),
    ("floor_lamp", ("lambader", "floor lamp")),
    ("pendant_lamp", ("sarkıt", "pendant")),
    ("lamp", ("lamba", "lamp", "aydınlatma")),
    ("rug", ("halı", "rug")),
    ("curtain", ("perde", "curtain")),
    ("mirror", ("ayna", "mirror")),
    ("wall_art", ("tablo", "wall art")),
    ("plant_pot", ("saksı", "plant pot")),
    ("storage_unit", ("depolama", "storage", "raf", "dolap", "vitrin", "büfe", "bufe", "cabinet")),
    ("decoration", ("dekor", "aksesuar", "decoration")),
]

SOURCE_CATEGORY_ROOM_HINTS = {
    "kitchen": [("kitchen", 0.68), ("dining_room", 0.58)],
    "dining_room": [("dining_room", 0.86), ("kitchen", 0.52)],
    "living_room": [("living_room", 0.82)],
    "bedroom": [("bedroom", 0.88)],
    "office": [("office", 0.80)],
    "hallway": [("hallway", 0.72)],
    "outdoor": [("outdoor", 0.72), ("balcony", 0.62)],
}


def normalize_source_category(value: Any) -> Optional[str]:
    if value in (None, "", [], {}):
        return None
    return str(value).strip().lower().replace(" ", "_").replace("-", "_")


STYLE_KEYWORDS = [
    ("japandi", ("japandi",)),
    ("scandinavian", ("iskandinav", "scandinavian")),
    ("industrial", ("endüstriyel", "industrial", "metal ayak")),
    ("bohemian", ("bohem", "bohemian")),
    ("rustic", ("rustik", "rustic")),
    ("luxury", ("lüks", "luxury", "gold", "mermer")),
    ("mid_century_modern", ("mid century", "retro")),
    ("traditional", ("geleneksel", "traditional")),
    ("farmhouse", ("farmhouse", "country")),
    ("coastal", ("coastal", "sahil")),
    ("classic", ("klasik", "classic")),
    ("art_deco", ("art deco",)),
    ("minimalist", ("minimal", "minimalist", "sade")),
    ("modern", ("modern", "çağdaş", "contemporary")),
    ("contemporary", ("contemporary", "çağdaş")),
]

MATERIAL_KEYWORDS = [
    ("walnut", "wood", ("ceviz", "walnut")),
    ("oak", "wood", ("meşe", "oak")),
    ("", "mdf", ("mdf",)),
    ("", "particle_board", ("suntalam", "yonga", "particle")),
    ("", "laminate", ("laminat", "laminate")),
    ("steel", "metal", ("metal", "çelik", "steel")),
    ("", "glass", ("cam", "glass")),
    ("", "marble", ("mermer", "marble")),
    ("", "stone", ("taş", "stone")),
    ("", "fabric", ("kumaş", "fabric")),
    ("", "velvet", ("kadife", "velvet")),
    ("", "leather", ("deri", "leather")),
    ("", "rattan", ("rattan", "hasır")),
    ("", "bamboo", ("bambu", "bamboo")),
    ("", "ceramic", ("seramik", "ceramic")),
    ("", "plastic", ("plastik", "plastic")),
    ("", "acrylic", ("akrilik", "acrylic")),
    ("", "wood", ("ahşap", "wood")),
]

COLOR_KEYWORDS = [
    ("walnut_brown", ("ceviz", "walnut")),
    ("oak_brown", ("meşe", "oak")),
    ("warm_brown", ("ahşap", "wood", "taba")),
    ("dark_brown", ("koyu kahve", "dark brown")),
    ("brown", ("kahve", "brown")),
    ("black", ("siyah", "black")),
    ("white", ("beyaz", "white")),
    ("gray", ("gri", "gray", "grey", "antrasit")),
    ("beige", ("bej", "beige")),
    ("cream", ("krem", "cream")),
    ("gold", ("gold", "altın")),
    ("silver", ("gümüş", "silver")),
    ("green", ("yeşil", "green")),
    ("navy", ("lacivert", "navy")),
    ("blue", ("mavi", "blue")),
    ("burgundy", ("bordo", "burgundy")),
    ("red", ("kırmızı", "red")),
    ("orange", ("turuncu", "orange")),
    ("yellow", ("sarı", "yellow")),
    ("pink", ("pembe", "pink")),
    ("purple", ("mor", "purple")),
    ("transparent", ("şeffaf", "transparent")),
    ("multicolor", ("çok renkli", "multicolor")),
]


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


def normalize_price(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    text = re.sub(r"[^\d,.\-]", "", text)
    if not text:
        return None
    if "," in text and "." in text:
        if text.rfind(",") > text.rfind("."):
            text = text.replace(".", "").replace(",", ".")
        else:
            text = text.replace(",", "")
    elif "," in text:
        text = text.replace(".", "").replace(",", ".")
    elif text.count(".") > 1:
        text = text.replace(".", "")
    elif "." in text and len(text.rsplit(".", 1)[-1]) == 3:
        text = text.replace(".", "")
    try:
        return float(text)
    except ValueError:
        return None


def _first_present(*values: Any) -> Any:
    for value in values:
        if value not in (None, "", [], {}):
            return value
    return None


def infer_brand(raw: Dict[str, Any]) -> str:
    metadata = raw.get("metadata") or {}
    brand_value = _first_present(raw.get("brand"), metadata.get("brand"), raw.get("source"))
    haystack = " ".join(
        str(part)
        for part in (brand_value, raw.get("url"), raw.get("name"))
        if part
    ).lower()
    if "vivense" in haystack:
        return "vivense"
    if "ikea" in haystack:
        return "ikea"
    if "istikbal" in haystack or "istikbal" in urlparse(str(raw.get("url", ""))).netloc:
        return "istikbal"
    return "unknown"


def collect_image_urls(raw: Dict[str, Any]) -> List[str]:
    metadata = raw.get("metadata") or {}
    candidates: List[Any] = [
        raw.get("image_urls"),
        raw.get("images"),
        raw.get("image_url"),
        raw.get("image"),
        metadata.get("image"),
        metadata.get("images"),
    ]
    urls: List[str] = []
    for candidate in candidates:
        if isinstance(candidate, str):
            urls.append(candidate)
        elif isinstance(candidate, list):
            urls.extend(str(item) for item in candidate if item)
    seen = set()
    cleaned = []
    for url in urls:
        url = url.strip()
        if url and url not in seen:
            cleaned.append(url)
            seen.add(url)
    return cleaned


def extract_product_category(raw: Dict[str, Any], metadata: Dict[str, Any]) -> Optional[str]:
    candidates = [
        raw.get("product_category"),
        raw.get("product_type"),
        raw.get("subcategory"),
        metadata.get("category"),
        metadata.get("categoryName"),
        metadata.get("productType"),
    ]
    for candidate in candidates:
        if candidate not in (None, "", [], {}):
            return str(candidate)
    return None


def normalize_raw_product(raw: Dict[str, Any], line_number: int) -> ProductRaw:
    metadata = raw.get("metadata") or {}
    offer = metadata.get("offers") if isinstance(metadata.get("offers"), dict) else {}
    product_id = str(
        _first_present(raw.get("id"), raw.get("product_id"), metadata.get("sku"), metadata.get("mpn"))
        or hashlib.sha1(
            f"{raw.get('url', '')}|{raw.get('name', '')}|{line_number}".encode("utf-8")
        ).hexdigest()[:16]
    )
    return ProductRaw(
        id=product_id,
        name=str(_first_present(raw.get("name"), metadata.get("name")) or ""),
        brand=infer_brand(raw),
        url=str(_first_present(raw.get("url"), offer.get("url")) or ""),
        price=normalize_price(_first_present(raw.get("price"), raw.get("price_try"), offer.get("price"))),
        currency=str(_first_present(raw.get("currency"), offer.get("priceCurrency")) or "TRY").upper(),
        description=str(_first_present(raw.get("description"), metadata.get("description")) or ""),
        image_urls=collect_image_urls(raw),
        category=extract_product_category(raw, metadata),
        source_category=normalize_source_category(raw.get("category")),
        metadata=metadata,
        raw=raw,
    )


def contains_any(text: str, needles: Iterable[str]) -> bool:
    return any(needle in text for needle in needles)


def infer_category(text: str, existing_category: Optional[str]) -> CategoryAttribute:
    category_text = f"{text} {existing_category or ''}".lower()
    for category, keywords in CATEGORY_KEYWORDS:
        if contains_any(category_text, keywords):
            confidence = 0.78 if existing_category and contains_any(str(existing_category).lower(), keywords) else 0.74
            return CategoryAttribute(primary=category, secondary=[], confidence=confidence)
    return CategoryAttribute(primary="unknown", secondary=[], confidence=0.18)


def infer_styles(text: str) -> List[StyleAttribute]:
    found = []
    for style, keywords in STYLE_KEYWORDS:
        if contains_any(text, keywords):
            confidence = 0.82 if style in {"modern", "minimalist"} else 0.72
            found.append(StyleAttribute(name=style, confidence=confidence))
    if not found:
        found.append(StyleAttribute(name="modern", confidence=0.42))
    return found[:3]


def color_temperature(color: str) -> str:
    if color in {"blue", "navy", "green", "gray", "silver", "transparent"}:
        return "cool" if color in {"blue", "navy", "green"} else "neutral"
    if color in {"black", "white", "gray", "silver", "transparent", "multicolor", "unknown"}:
        return "neutral"
    return "warm"


def infer_colors(text: str) -> ColorAttributes:
    found: List[str] = []
    for color, keywords in COLOR_KEYWORDS:
        if color in COLOR_TAXONOMY and contains_any(text, keywords):
            found.append(color)
    if not found:
        found = ["warm_brown" if contains_any(text, ("wood", "ahşap", "ceviz", "meşe")) else "beige"]
    dominant = found[0]
    secondary = found[1:3] or (["black"] if dominant in {"warm_brown", "walnut_brown", "oak_brown"} else [])
    return ColorAttributes(
        dominant=ColorAttribute(
            name=dominant,
            hex=COLOR_HEX[dominant],
            temperature=color_temperature(dominant),
            confidence=0.68 if dominant != "beige" else 0.38,
        ),
        secondary=[
            ColorAttribute(
                name=color,
                hex=COLOR_HEX[color],
                temperature=color_temperature(color),
                confidence=0.45,
            )
            for color in secondary
        ],
    )


def verification_status(confidence: float) -> str:
    if confidence >= 0.78:
        return "high_confidence"
    if confidence >= 0.55:
        return "medium_confidence"
    return "low_confidence"


def infer_materials(text: str) -> MaterialAttributes:
    found = []
    for subtype, material, keywords in MATERIAL_KEYWORDS:
        if material in MATERIAL_TAXONOMY and contains_any(text, keywords):
            found.append((material, subtype or "unknown", 0.72))
    if not found:
        found.append(("wood", "unknown", 0.34))
    dominant_material, subtype, confidence = found[0]
    secondary = []
    for material, secondary_subtype, secondary_confidence in found[1:3]:
        secondary.append(
            MaterialAttribute(
                main=material,
                subtype=secondary_subtype,
                finish="unknown",
                confidence=secondary_confidence,
                verification_status=verification_status(secondary_confidence),
            )
        )
    return MaterialAttributes(
        dominant=MaterialAttribute(
            main=dominant_material,
            subtype=subtype,
            finish="matte" if dominant_material in {"wood", "mdf", "particle_board"} else "unknown",
            confidence=confidence,
            verification_status=verification_status(confidence),
        ),
        secondary=secondary,
    )


def _flatten_metadata_values(value: Any) -> Iterable[str]:
    if value in (None, "", [], {}):
        return
    if isinstance(value, dict):
        for child in value.values():
            yield from _flatten_metadata_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from _flatten_metadata_values(child)
    else:
        yield str(value)


def _dimension_search_text(product: ProductRaw) -> str:
    raw = product.raw or {}
    metadata = product.metadata or {}
    pieces = [
        product.name,
        product.description,
        product.category or "",
        product.source_category or "",
        product.url,
        raw.get("size"),
        raw.get("dimensions"),
        raw.get("dimensions_cm"),
        raw.get("attributes"),
        metadata,
    ]
    return " ".join(_flatten_metadata_values(pieces)).lower()


def infer_dimensions(product: ProductRaw) -> DimensionsCm:
    text = _dimension_search_text(product)
    patterns = [
        r"(?<!\d)(\d{2,3}(?:[.,]\d+)?)\s*(?:cm)?\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:cm)?\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)[\s_-]*cm\b",
        r"(?<!\d)(\d{2,3}(?:[.,]\d+)?)\s*cm\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)\s*cm\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)[\s_-]*cm\b",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            width, depth, height = (float(part.replace(",", ".")) for part in match.groups())
            return DimensionsCm(width=width, depth=depth, height=height, confidence=0.86)

    two_dimension_patterns = [
        r"(?<!\d)(\d{2,3}(?:[.,]\d+)?)\s*(?:cm)?\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)[\s_-]*cm\b",
        r"(?<!\d)(\d{2,3}(?:[.,]\d+)?)\s*cm\s*[x×]\s*(\d{2,3}(?:[.,]\d+)?)\s*cm\b",
    ]
    for pattern in two_dimension_patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            width, height = (float(part.replace(",", ".")) for part in match.groups())
            return DimensionsCm(width=width, depth=None, height=height, confidence=0.62)

    labeled_values = {}
    label_patterns = {
        "width": ("width", "genislik", "genişlik", "en"),
        "depth": ("depth", "derinlik", "boy"),
        "height": ("height", "yukseklik", "yükseklik"),
    }
    for field, labels in label_patterns.items():
        for label in labels:
            match = re.search(rf"{label}\s*[:=]?\s*(\d{{2,3}}(?:[.,]\d+)?)[\s_-]*cm\b", text, flags=re.IGNORECASE)
            if match:
                labeled_values[field] = float(match.group(1).replace(",", "."))
                break

    if labeled_values:
        return DimensionsCm(
            width=labeled_values.get("width"),
            depth=labeled_values.get("depth"),
            height=labeled_values.get("height"),
            confidence=0.74 if len(labeled_values) == 3 else 0.52,
        )

    return DimensionsCm(width=None, depth=None, height=None, confidence=0.0)


def infer_rooms(category: str, text: str, source_category: Optional[str] = None) -> List[RoomCompatibility]:
    category_rooms = {
        "sofa": [("living_room", 0.94)],
        "armchair": [("living_room", 0.88), ("bedroom", 0.45), ("office", 0.42)],
        "coffee_table": [("living_room", 0.95)],
        "side_table": [("living_room", 0.78), ("bedroom", 0.62)],
        "tv_unit": [("living_room", 0.92)],
        "bed": [("bedroom", 0.96)],
        "wardrobe": [("bedroom", 0.90), ("hallway", 0.45)],
        "dresser": [("bedroom", 0.85)],
        "nightstand": [("bedroom", 0.95)],
        "desk": [("office", 0.86), ("bedroom", 0.45)],
        "office_chair": [("office", 0.95)],
        "dining_table": [("dining_room", 0.92), ("kitchen", 0.55)],
        "dining_chair": [("dining_room", 0.90), ("kitchen", 0.52)],
        "rug": [("living_room", 0.70), ("bedroom", 0.55)],
        "curtain": [("living_room", 0.65), ("bedroom", 0.62)],
        "plant_pot": [("living_room", 0.62), ("balcony", 0.60), ("outdoor", 0.48)],
    }
    rooms = list(category_rooms.get(category, []))
    source_rooms = SOURCE_CATEGORY_ROOM_HINTS.get(normalize_source_category(source_category) or "", [])
    for room, confidence in source_rooms:
        if room not in {existing_room for existing_room, _ in rooms}:
            rooms.append((room, confidence))
    if not rooms:
        rooms = [("unknown", 0.18)]
    if "yatak odası" in text or "yatak-odasi" in text or "bedroom" in text:
        rooms = [("bedroom", 0.86)] + [room for room in rooms if room[0] != "bedroom"]
    if "yemek odası" in text or "yemek-odasi" in text or "dining" in text:
        rooms = [("dining_room", 0.84)] + [room for room in rooms if room[0] != "dining_room"]
    return [RoomCompatibility(room=room, confidence=confidence) for room, confidence in rooms if room in ROOM_TAXONOMY]


def infer_shape(category: str, text: str) -> ShapeAttribute:
    if contains_any(text, ("yuvarlak", "round", "oval")):
        return ShapeAttribute(main="round", edge_style="rounded", shape_language="organic", confidence=0.74)
    if contains_any(text, ("kavis", "rounded", "soft")):
        return ShapeAttribute(main="rectangular", edge_style="rounded", shape_language="organic", confidence=0.64)
    if category in {"coffee_table", "dining_table", "desk", "tv_unit", "console_table"}:
        return ShapeAttribute(main="rectangular", edge_style="straight", shape_language="geometric", confidence=0.54)
    return ShapeAttribute(main="compact", edge_style="unknown", shape_language="balanced", confidence=0.32)


def fallback_enrichment(product: ProductRaw) -> tuple[FurnitureAttributes, SemanticText]:
    text = _dimension_search_text(product)
    category = infer_category(text, product.category)
    styles = infer_styles(text)
    colors = infer_colors(text)
    materials = infer_materials(text)
    dimensions = infer_dimensions(product)
    rooms = infer_rooms(category.primary, text, product.source_category)
    shape = infer_shape(category.primary, text)

    visual_features = []
    if shape.edge_style == "rounded":
        visual_features.append("soft_edges")
    if category.primary in {"coffee_table", "side_table", "console_table", "desk"}:
        visual_features.extend(["thin_legs", "compact_form"])
    if not visual_features:
        visual_features = ["clean_lines", "balanced_form"]

    dominant_color = colors.dominant.name
    dominant_material = materials.dominant.main
    style_names = [style.name for style in styles if style.name != "unknown"]
    room_names = [room.room for room in rooms if room.room != "unknown"]
    quality_tier = "budget" if product.price and product.price < 2500 else "mid_range"
    if product.price and product.price > 25000:
        quality_tier = "premium"

    attributes = FurnitureAttributes(
        category=category,
        styles=styles,
        colors=colors,
        materials=materials,
        dimensions_cm=dimensions,
        room_compatibility=rooms,
        shape=shape,
        visual_features=visual_features[:5],
        design_tags=[
            tag
            for tag in [
                "small_room_friendly" if category.primary in {"coffee_table", "side_table", "desk"} else "",
                "warm_look" if colors.dominant.temperature == "warm" else "",
                "space_saving" if "compact_form" in visual_features else "",
            ]
            if tag
        ],
        spatial_feel="space_opening" if category.primary in {"coffee_table", "side_table", "lamp"} else "balanced",
        visual_weight="light" if category.primary in {"coffee_table", "side_table", "chair", "lamp"} else "medium",
        texture_intensity="medium",
        contrast_level="low" if len(colors.secondary) <= 1 else "medium",
        usage_intent=infer_usage_intent(category.primary),
        quality_tier=quality_tier,
        assembly_required="unknown",
    )

    semantic_text = SemanticText(
        aesthetic_caption=" ".join(
            part
            for part in [
                dominant_color,
                " ".join(style_names[:2]),
                dominant_material,
                category.primary,
                "with",
                " ".join(visual_features[:2]),
            ]
            if part
        ),
        functional_caption=f"{category.primary} suitable for {', '.join(room_names[:2]) or 'living_room'}",
        material_caption=f"{materials.dominant.finish} {materials.dominant.subtype} {dominant_material} with {dominant_color} finish",
        attribute_caption=" ".join(
            value
            for value in [
                category.primary,
                *style_names,
                dominant_color,
                materials.dominant.subtype,
                dominant_material,
                *(room_names[:2]),
            ]
            if value and value != "unknown"
        ),
    )
    return attributes, semantic_text


def infer_usage_intent(category: str) -> List[str]:
    mapping = {
        "coffee_table": ["coffee_serving", "decor_display"],
        "side_table": ["side_storage", "decor_display"],
        "sofa": ["seating", "relaxing"],
        "armchair": ["reading", "accent_seating"],
        "dining_table": ["dining", "hosting"],
        "dining_chair": ["dining_seating"],
        "bed": ["sleeping", "resting"],
        "wardrobe": ["clothing_storage"],
        "dresser": ["clothing_storage", "surface_display"],
        "nightstand": ["bedside_storage"],
        "desk": ["working", "studying"],
        "office_chair": ["working", "ergonomic_seating"],
        "lamp": ["ambient_lighting"],
        "floor_lamp": ["ambient_lighting"],
        "pendant_lamp": ["overhead_lighting"],
        "rug": ["floor_softening", "zone_definition"],
        "mirror": ["reflection", "space_brightening"],
        "decoration": ["decor_display"],
    }
    return mapping.get(category, ["home_furnishing"])



def build_vertex_prompt(product: ProductRaw) -> str:
    return f"""
You are an interior design product enrichment agent for an agentic shopping RAG system.
Return ONLY valid JSON with exactly these top-level keys: attributes, semantic_text.

Product metadata:
- id: {product.id}
- name: {product.name}
- brand: {product.brand}
- url: {product.url}
- price: {product.price}
- currency: {product.currency}
- existing_product_category: {product.category}
- source_category: {product.source_category}
- description: {product.description}
- image_urls: {json.dumps(product.image_urls, ensure_ascii=False)}
- dimension_search_text: {_dimension_search_text(product)}

Rules:
- Use only taxonomy labels.
- Category primary must be one of: sofa, armchair, chair, dining_chair, dining_table, coffee_table, side_table, console_table, tv_unit, bed, wardrobe, dresser, nightstand, bookshelf, desk, office_chair, lamp, floor_lamp, pendant_lamp, rug, curtain, mirror, wall_art, plant_pot, decoration, storage_unit, unknown.
- Styles must be one of: modern, minimalist, scandinavian, industrial, bohemian, rustic, luxury, mid_century_modern, traditional, farmhouse, contemporary, japandi, coastal, classic, art_deco, unknown.
- Rooms must be one of: living_room, bedroom, dining_room, kitchen, office, hallway, balcony, bathroom, kids_room, outdoor, unknown.
- Material main must be one of: wood, metal, glass, marble, stone, plastic, fabric, leather, velvet, ceramic, rattan, bamboo, mdf, particle_board, laminate, acrylic, unknown.
- Color names must be one of: white, black, gray, beige, cream, brown, warm_brown, walnut_brown, oak_brown, dark_brown, gold, silver, green, blue, navy, red, burgundy, orange, yellow, pink, purple, transparent, multicolor, unknown.
- Temperature must be one of: warm, cool, neutral, unknown.
- visual_weight must be one of: very_light, light, medium, heavy, very_heavy, unknown.
- spatial_feel must be one of: space_opening, balanced, space_filling, bulky, unknown.
- verification_status must be one of: high_confidence, medium_confidence, low_confidence, unknown.
- source_category is the crawler category page hint; use it for room compatibility only, not as proof of product type.
- Do not invent product URL, brand, price, currency, or exact dimensions.
- If exact dimensions are not present in product metadata, description, name, or URL, set width/depth/height to null and confidence to 0.0.
- If unsure, give the best prediction with low confidence instead of using unknown.
- Generate aesthetic_caption, functional_caption, material_caption, and attribute_caption.

JSON shape:
{{
  "attributes": {{
    "category": {{"primary": "coffee_table", "secondary": [], "confidence": 0.0}},
    "styles": [{{"name": "modern", "confidence": 0.0}}],
    "colors": {{
      "dominant": {{"name": "warm_brown", "hex": "#6B4F3A", "temperature": "warm", "confidence": 0.0}},
      "secondary": []
    }},
    "materials": {{
      "dominant": {{"main": "wood", "subtype": "walnut", "finish": "matte", "confidence": 0.0, "verification_status": "low_confidence"}},
      "secondary": []
    }},
    "dimensions_cm": {{"width": null, "depth": null, "height": null, "confidence": 0.0}},
    "room_compatibility": [{{"room": "living_room", "confidence": 0.0}}],
    "shape": {{"main": "rectangular", "edge_style": "rounded", "shape_language": "organic", "confidence": 0.0}},
    "visual_features": ["thin_legs"],
    "design_tags": ["small_room_friendly"],
    "spatial_feel": "balanced",
    "visual_weight": "medium",
    "texture_intensity": "medium",
    "contrast_level": "low",
    "usage_intent": ["decor_display"],
    "quality_tier": "mid_range",
    "assembly_required": "unknown"
  }},
  "semantic_text": {{
    "aesthetic_caption": "",
    "functional_caption": "",
    "material_caption": "",
    "attribute_caption": ""
  }}
}}
""".strip()


class VertexEnricher:
    def __init__(self):
        self.client = VertexAIClient()

    def enrich(self, product: ProductRaw) -> tuple[FurnitureAttributes, SemanticText]:
        data = self.client.generate_json(build_vertex_prompt(product), temperature=0.2)
        return (
            FurnitureAttributes.model_validate(data.get("attributes", {})),
            SemanticText.model_validate(data.get("semantic_text", {})),
        )


def get_thread_vertex_enricher() -> VertexEnricher:
    enricher = getattr(_THREAD_LOCAL, "vertex_enricher", None)
    if enricher is None:
        enricher = VertexEnricher()
        _THREAD_LOCAL.vertex_enricher = enricher
    return enricher


def make_enriched_product(product: ProductRaw, attributes: FurnitureAttributes, semantic_text: SemanticText) -> EnrichedProduct:
    return EnrichedProduct(
        id=product.id,
        name=product.name,
        brand=product.brand,
        url=product.url,
        price=product.price,
        currency=product.currency,
        description=product.description,
        image_urls=product.image_urls,
        attributes=attributes,
        semantic_text=semantic_text,
        embedding_metadata=EmbeddingMetadata(
            image_model="vertex_ai_or_product_image_url",
            text_model="text_embedding_model",
            caption_prompt_version="v1",
            attribute_schema_version="v1",
        ),
        latent_cluster=LatentCluster(),
    )


def iter_jsonl(path: Path) -> Iterable[tuple[int, Optional[Dict[str, Any]], Optional[Exception]]]:
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            try:
                yield line_number, json.loads(line), None
            except Exception as exc:
                yield line_number, None, exc


def model_to_json_line(model: EnrichedProduct) -> str:
    return json.dumps(model.model_dump(mode="json"), ensure_ascii=False)


def make_error_payload(line_number: int, raw: Dict[str, Any], error: Exception) -> Dict[str, Any]:
    return {
        "line_number": line_number,
        "id": raw.get("id") or raw.get("product_id"),
        "name": raw.get("name"),
        "url": raw.get("url"),
        "error": str(error),
    }


def write_error(handle, payload: Dict[str, Any]) -> None:
    handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def limited_rows(
    rows: Iterable[tuple[int, Optional[Dict[str, Any]], Optional[Exception]]],
    limit: Optional[int],
) -> List[tuple[int, Optional[Dict[str, Any]], Optional[Exception]]]:
    selected = []
    for row in rows:
        if limit is not None and len(selected) >= limit:
            break
        selected.append(row)
    return selected


def enrich_row(
    row: tuple[int, Optional[Dict[str, Any]], Optional[Exception]],
    use_vertex: bool,
) -> Tuple[int, Optional[str], Optional[Dict[str, Any]], Optional[str]]:
    line_number, raw, parse_error = row
    try:
        if parse_error is not None or raw is None:
            raise parse_error or ValueError("Invalid JSONL row")

        product = normalize_raw_product(raw, line_number)
        if use_vertex:
            try:
                attributes, semantic_text = get_thread_vertex_enricher().enrich(product)
                warning = None
            except Exception as exc:
                warning = f"Vertex AI failed for {product.id}; fallback used: {exc}"
                attributes, semantic_text = fallback_enrichment(product)
        else:
            warning = None
            attributes, semantic_text = fallback_enrichment(product)

        enriched = make_enriched_product(product, attributes, semantic_text)
        return line_number, model_to_json_line(enriched), None, warning
    except Exception as exc:
        return line_number, None, make_error_payload(line_number, raw or {}, exc), None


def enrich_file(
    input_path: Path,
    output_path: Path,
    error_path: Path,
    limit: Optional[int],
    parallel_requests: int = 1,
) -> None:
    if parallel_requests <= 0:
        raise ValueError("parallel_requests must be greater than zero")

    use_vertex = False
    if os.getenv("PROJECT_ID"):
        try:
            # Validate configuration before worker threads start. Each worker thread
            # builds its own client lazily, so no mutable Vertex client is shared.
            probe = VertexEnricher()
            print(f"Vertex AI enrichment enabled with model {probe.client.model_id}.")
            use_vertex = True
        except Exception as exc:
            print(f"Vertex AI unavailable, using fallback mode: {exc}")
    else:
        print("PROJECT_ID not found. Running deterministic fallback enrichment.")

    rows = limited_rows(iter_jsonl(input_path), limit)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    error_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8") as out, error_path.open("w", encoding="utf-8") as errors:
        if parallel_requests == 1:
            # Serial path: tqdm wraps the input row-by-row (each iteration IS the work).
            serial_iter = tqdm(rows, desc="enriching", total=len(rows)) if tqdm else rows
            for row in serial_iter:
                _, output_line, error_payload, warning = enrich_row(row, use_vertex)
                if warning:
                    print(warning)
                if error_payload:
                    write_error(errors, error_payload)
                elif output_line:
                    out.write(output_line + "\n")
            return

        with ThreadPoolExecutor(max_workers=parallel_requests) as executor:
            # Parallel path: tqdm MUST wrap the results iterator, not the input.
            # executor.map() submits all tasks nearly instantly, so wrapping rows
            # would show 100% before any HTTP call completes and then hang silently.
            results = executor.map(lambda row: enrich_row(row, use_vertex), rows)
            if tqdm:
                results = tqdm(results, desc="enriching", total=len(rows))
            for _, output_line, error_payload, warning in results:
                if warning:
                    print(warning)
                if error_payload:
                    write_error(errors, error_payload)
                elif output_line:
                    out.write(output_line + "\n")

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Enrich furniture products for agentic shopping RAG.")
    parser.add_argument("--input", default="products.jsonl", help="Input products JSONL path.")
    parser.add_argument("--output", default="enriched_products.jsonl", help="Output enriched JSONL path.")
    parser.add_argument("--errors", default="enrichment_errors.jsonl", help="Failed products JSONL path.")
    parser.add_argument("--limit", type=int, default=None, help="Optional max products to process.")
    parser.add_argument("--parallel-requests", type=int, default=1, help="Maximum concurrent Vertex AI requests.")
    return parser.parse_args()


def main() -> None:
    load_env()
    args = parse_args()
    input_path = resolve_input_path(args.input)
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")
    enrich_file(
        input_path=input_path,
        output_path=Path(args.output),
        error_path=Path(args.errors),
        limit=args.limit,
        parallel_requests=args.parallel_requests,
    )


if __name__ == "__main__":
    main()

from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from app.utils.geometry import polygons_overlap

NormalizedPolygon = list[list[float]]
PlacementRejection = dict[str, Any]


def image_size(path: Path, fallback: tuple[int, int] = (1280, 720)) -> tuple[int, int]:
    try:
        with Image.open(path) as image:
            return image.size
    except Exception:
        return fallback


def pixel_to_normalized_polygon(
    polygon: list[list[float]],
    image_width: int,
    image_height: int,
) -> NormalizedPolygon:
    width = max(image_width, 1)
    height = max(image_height, 1)
    return [
        [min(max(x / width, 0.0), 1.0), min(max(y / height, 0.0), 1.0)]
        for x, y in polygon
    ]


def normalized_to_pixel_polygon(
    polygon: NormalizedPolygon,
    image_width: int,
    image_height: int,
) -> list[list[float]]:
    # Backend APIs store placement polygons as normalized 0.0-1.0 values.
    # Convert back to original image pixels only at image-render time.
    return [[x * image_width, y * image_height] for x, y in polygon]


def normalize_polygon(
    polygon: list[list[float]] | None,
    image_width: int,
    image_height: int,
) -> NormalizedPolygon:
    if not polygon:
        return []
    max_coord = max(max(abs(point[0]), abs(point[1])) for point in polygon)
    if max_coord <= 1.0:
        return [
            [min(max(float(x), 0.0), 1.0), min(max(float(y), 0.0), 1.0)]
            for x, y in polygon
        ]
    return pixel_to_normalized_polygon(polygon, image_width, image_height)


def polygon_center(polygon: NormalizedPolygon) -> tuple[float, float]:
    if not polygon:
        return 0.5, 0.75
    return (
        sum(point[0] for point in polygon) / len(polygon),
        sum(point[1] for point in polygon) / len(polygon),
    )


def fallback_floor_polygon(top: float = 0.5) -> NormalizedPolygon:
    clamped_top = min(max(top, 0.45), 0.55)
    return [[0.0, clamped_top], [1.0, clamped_top], [1.0, 1.0], [0.0, 1.0]]


def point_inside_floor(point: tuple[float, float], floor_polygon: NormalizedPolygon) -> bool:
    if not floor_polygon:
        return False
    x, y = point
    inside = False
    previous = floor_polygon[-1]
    for current in floor_polygon:
        xi, yi = current
        xj, yj = previous
        crosses_y = (yi > y) != (yj > y)
        if crosses_y:
            x_intersection = (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi
            if x < x_intersection:
                inside = not inside
        previous = current
    return inside


def polygon_inside_normalized_image(polygon: NormalizedPolygon) -> bool:
    return bool(polygon) and all(0.0 <= x <= 1.0 and 0.0 <= y <= 1.0 for x, y in polygon)


def placement_polygon_for_point(
    center_x: float,
    floor_y: float,
    role: str,
) -> NormalizedPolygon:
    width, height = _role_size(role)
    x1 = center_x - width / 2
    x2 = center_x + width / 2
    y2 = floor_y
    y1 = floor_y - height
    return [[x1, y1], [x2, y1], [x2, y2], [x1, y2]]


def validate_placement_polygon(
    polygon: NormalizedPolygon,
    floor_polygon: NormalizedPolygon,
    existing_furniture: list[NormalizedPolygon] | None = None,
    overlap_threshold: float = 0.18,
) -> tuple[bool, list[str]]:
    reasons = []
    if not polygon_inside_normalized_image(polygon):
        reasons.append("outside_image")
    floor_contact = (
        ((polygon[2][0] + polygon[3][0]) / 2, (polygon[2][1] + polygon[3][1]) / 2)
        if len(polygon) >= 4
        else polygon_center(polygon)
    )
    if not point_inside_floor(floor_contact, floor_polygon):
        reasons.append("center_not_on_floor")
    for existing in existing_furniture or []:
        if polygons_overlap(polygon, existing) > overlap_threshold:
            reasons.append("overlaps_existing_furniture")
            break
    return not reasons, reasons


def build_floor_placements(
    products: list[dict],
    image_width: int,
    image_height: int,
    room_analysis: dict | None = None,
) -> tuple[list[dict], dict]:
    room_analysis = room_analysis or {}
    floor_polygon = _floor_polygon_from_analysis(room_analysis, image_width, image_height)
    existing = [
        normalize_polygon(item.get("polygon"), image_width, image_height)
        for item in room_analysis.get("existing_furniture", [])
        if item.get("polygon")
    ]
    reserved = list(existing)
    placements = []
    accepted = []
    rejected: list[PlacementRejection] = []
    count = max(len(products), 1)

    for index, product in enumerate(products):
        role = product.get("role", "")
        x = (index + 1) / (count + 1)
        y = 0.78 if index % 2 == 0 else 0.88
        polygon = placement_polygon_for_point(x, y, role)
        valid, reasons = validate_placement_polygon(polygon, floor_polygon, reserved)
        if not valid:
            rejected.append(_rejection(product, polygon, reasons))
            fallback_polygon = _first_valid_fallback_polygon(index, role, floor_polygon, reserved)
            if fallback_polygon:
                polygon = fallback_polygon
                valid, reasons = validate_placement_polygon(polygon, floor_polygon, reserved)

        if valid:
            placement = {
                "product_id": product["product_id"],
                "role": role,
                "placement_type": "new",
                "target_polygon": polygon,
                "depth_order": index,
                "confidence": 0.62,
                "notes": "Validated fallback floor placement using normalized coordinates.",
            }
            placements.append(placement)
            accepted.append(placement)
            reserved.append(polygon)
        else:
            rejected.append(_rejection(product, polygon, reasons or ["no_valid_floor_point"]))

    debug = {
        "coordinate_system": "normalized_0_1",
        "image_width": image_width,
        "image_height": image_height,
        "floor_polygon": floor_polygon,
        "existing_furniture": existing,
        "accepted": accepted,
        "rejected": rejected,
    }
    return placements, debug


def draw_placement_debug_image(
    room_image_path: Path,
    output_path: Path,
    debug: dict,
) -> None:
    width = int(debug.get("image_width") or 1280)
    height = int(debug.get("image_height") or 720)
    try:
        base = Image.open(room_image_path).convert("RGBA")
    except Exception:
        base = Image.new("RGBA", (width, height), (245, 241, 234, 255))
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    floor = normalized_to_pixel_polygon(debug.get("floor_polygon", []), *base.size)
    if floor:
        draw.polygon(_points(floor), fill=(20, 110, 180, 56), outline=(20, 110, 180, 210))

    for placement in debug.get("accepted", []):
        polygon = normalized_to_pixel_polygon(placement.get("target_polygon", []), *base.size)
        draw.polygon(_points(polygon), outline=(20, 170, 80, 255), width=4)
        cx, cy = polygon_center(placement.get("target_polygon", []))
        _draw_point(draw, cx * base.size[0], cy * base.size[1], (20, 170, 80, 255))

    for rejected in debug.get("rejected", []):
        polygon = normalized_to_pixel_polygon(rejected.get("polygon", []), *base.size)
        if polygon:
            draw.polygon(_points(polygon), outline=(220, 50, 45, 255), width=3)
            cx, cy = polygon_center(rejected.get("polygon", []))
            _draw_point(draw, cx * base.size[0], cy * base.size[1], (220, 50, 45, 255))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    Image.alpha_composite(base, overlay).convert("RGB").save(output_path)


def _floor_polygon_from_analysis(
    room_analysis: dict,
    image_width: int,
    image_height: int,
) -> NormalizedPolygon:
    zones = room_analysis.get("available_placement_zones") or []
    for zone in zones:
        label = str(zone.get("label") or "").lower()
        if "floor" in label and zone.get("polygon"):
            return normalize_polygon(zone["polygon"], image_width, image_height)
    return fallback_floor_polygon()


def _first_valid_fallback_polygon(
    offset: int,
    role: str,
    floor_polygon: NormalizedPolygon,
    existing: list[NormalizedPolygon],
) -> NormalizedPolygon | None:
    floor_top = min(point[1] for point in floor_polygon) if floor_polygon else 0.5
    candidates = [
        (0.25, max(0.72, floor_top + 0.22)),
        (0.5, max(0.78, floor_top + 0.28)),
        (0.75, max(0.82, floor_top + 0.32)),
        (0.35, 0.9),
        (0.65, 0.9),
    ]
    for index in range(len(candidates)):
        x, y = candidates[(offset + index) % len(candidates)]
        polygon = placement_polygon_for_point(x, min(y, 0.96), role)
        valid, _ = validate_placement_polygon(polygon, floor_polygon, existing)
        if valid:
            return polygon
    return None


def _role_size(role: str) -> tuple[float, float]:
    """Normalized width and height for a furniture role's placement polygon.

    Width and height are expressed as fractions of the full image.
    Height is the vertical extent of the polygon (visual height in the image).
    """
    sizes = {
        # Large floor pieces
        "bed": (0.35, 0.22),
        "sofa": (0.30, 0.16),
        "dining_table": (0.28, 0.18),
        "desk": (0.24, 0.14),
        "tv_unit": (0.26, 0.10),
        "console_table": (0.22, 0.10),
        # Medium pieces
        "armchair": (0.16, 0.16),
        "wardrobe": (0.18, 0.28),
        "bookshelf": (0.14, 0.26),
        "dresser": (0.18, 0.16),
        "storage_unit": (0.16, 0.18),
        "dining_chair": (0.10, 0.14),
        "office_chair": (0.12, 0.14),
        "coffee_table": (0.20, 0.10),
        # Small accessories
        "nightstand": (0.10, 0.12),
        "side_table": (0.10, 0.12),
        "floor_lamp": (0.08, 0.22),
        "lamp": (0.08, 0.14),
        "mirror": (0.12, 0.18),
        "plant_pot": (0.08, 0.12),
        # Floor coverings
        "carpet": (0.36, 0.14),
        "rug": (0.34, 0.12),
        "curtain": (0.14, 0.30),
    }
    return sizes.get(role, (0.18, 0.14))


def _rejection(product: dict, polygon: NormalizedPolygon, reasons: list[str]) -> PlacementRejection:
    return {
        "product_id": product.get("product_id"),
        "role": product.get("role"),
        "polygon": polygon,
        "reasons": reasons,
    }


def _points(polygon: list[list[float]]) -> list[tuple[float, float]]:
    return [(x, y) for x, y in polygon]


def _draw_point(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    color: tuple[int, int, int, int],
) -> None:
    radius = 8
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)

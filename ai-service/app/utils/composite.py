from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from app.storage.local_storage import LocalImageStorage
from app.utils.placement import normalized_to_pixel_polygon


def render_placeholder_composite(
    *,
    storage: LocalImageStorage,
    room_image_path: str,
    products: list[dict],
    output_relative_path: str,
) -> tuple[str, Path]:
    """Render a simple Sprint 1 placement preview.

    The API stores placement polygons in normalized coordinates. This renderer
    converts them back to original room-image pixels only at draw time.
    """
    room_path = storage.resolve_room_image(room_image_path)
    output_path = storage.resolve_generated_image(output_relative_path)
    try:
        canvas = Image.open(room_path).convert("RGBA")
    except Exception:
        canvas = Image.new("RGBA", (1280, 720), (245, 241, 234, 255))

    draw = ImageDraw.Draw(canvas)
    for product in products:
        polygon = product.get("polygon") or []
        if not polygon:
            continue
        pixel_polygon = normalized_to_pixel_polygon(polygon, *canvas.size)
        x1, y1, x2, y2 = _bbox(pixel_polygon)
        furniture = _load_product_image(
            storage,
            product.get("image_path"),
            int(x2 - x1),
            int(y2 - y1),
        )
        if furniture is not None:
            canvas.alpha_composite(furniture, (int(x1), int(y1)))
        else:
            draw.rounded_rectangle(
                (x1, y1, x2, y2),
                radius=10,
                fill=(91, 124, 111, 150),
                outline=(28, 38, 35, 230),
                width=3,
            )
            label = str(product.get("role") or product.get("name") or "item")
            draw.text((x1 + 8, y1 + 8), label[:28], fill=(255, 255, 255, 255), font=_font())

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_path)
    return output_relative_path, output_path


def _load_product_image(
    storage: LocalImageStorage,
    image_path: str | None,
    width: int,
    height: int,
) -> Image.Image | None:
    if not image_path or image_path.startswith("http"):
        return None
    path = storage.resolve_product_image(image_path)
    if not path.exists():
        return None
    try:
        with Image.open(path) as image:
            resized = image.convert("RGBA").resize((max(width, 1), max(height, 1)))
            return resized
    except Exception:
        return None


def _bbox(polygon: list[list[float]]) -> tuple[float, float, float, float]:
    xs = [point[0] for point in polygon]
    ys = [point[1] for point in polygon]
    return min(xs), min(ys), max(xs), max(ys)


def _font() -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default()
    except Exception:
        return ImageFont.ImageFont()

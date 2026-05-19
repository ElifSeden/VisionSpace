"""Sprint 1+2 composite renderer.

Renders furniture images onto the room photograph with:
- Perspective-aware scaling (Sprint 2)
- Bottom-center anchoring (Sprint 2)
- Soft shadow rendering (Sprint 2)
- Optional horizontal perspective skew (Sprint 2)

In normal mode, unavailable product images are skipped instead of drawing the
green placement rectangle. The rectangle is a debug-only placement aid.
"""

from io import BytesIO
from pathlib import Path

import structlog
from PIL import Image, ImageDraw, ImageFont
import requests

from app.core.config import get_settings
from app.storage.local_storage import LocalImageStorage
from app.utils.perspective import (
    anchor_bottom_center,
    apply_perspective_skew,
    compute_furniture_dimensions,
    compute_perspective_scale,
    generate_shadow,
)
from app.utils.placement import normalized_to_pixel_polygon

logger = structlog.get_logger(__name__)


def render_placeholder_composite(
    *,
    storage: LocalImageStorage,
    room_image_path: str,
    products: list[dict],
    output_relative_path: str,
) -> tuple[str, Path]:
    """Render a perspective-aware placement preview.

    The API stores placement polygons in normalized coordinates.  This renderer
    converts them back to original room-image pixels only at draw time.

    Sprint 2 improvements over the original flat paste:
    - Furniture is scaled based on its vertical (depth) position.
    - The placement point is treated as the furniture's bottom-center anchor.
    - A soft shadow is composited beneath the furniture.
    - An optional horizontal perspective skew can be applied.
    """
    settings = get_settings()
    room_path = storage.resolve_room_image(room_image_path)
    output_path = storage.resolve_generated_image(output_relative_path)

    try:
        canvas = Image.open(room_path).convert("RGBA")
    except Exception:
        canvas = Image.new("RGBA", (1280, 720), (245, 241, 234, 255))

    image_width, image_height = canvas.size
    draw = ImageDraw.Draw(canvas)

    for product in products:
        polygon = product.get("polygon") or []
        if not polygon:
            continue

        # ---- Extract placement anchor (bottom-center of polygon) --------
        # The polygon is normalized [[x1,y1], [x2,y1], [x2,y2], [x1,y2]].
        norm_xs = [pt[0] for pt in polygon]
        norm_ys = [pt[1] for pt in polygon]
        center_x_norm = (min(norm_xs) + max(norm_xs)) / 2.0
        floor_y_norm = max(norm_ys)  # bottom edge = floor contact

        # Convert to pixel coordinates.
        placement_x_px = center_x_norm * image_width
        placement_y_px = floor_y_norm * image_height

        # ---- Load furniture image ----------------------------------------
        furniture = _load_product_image_raw(storage, product.get("image_path"))

        if furniture is not None:
            _render_furniture_with_perspective(
                canvas=canvas,
                furniture=furniture,
                center_x_norm=center_x_norm,
                floor_y_norm=floor_y_norm,
                placement_x_px=placement_x_px,
                placement_y_px=placement_y_px,
                image_width=image_width,
                image_height=image_height,
                settings=settings,
                product=product,
            )
        elif settings.debug_placement:
            # Debug-only fallback: the green rectangle is a placement mask, not
            # a production render. It must never replace the final image.
            pixel_polygon = normalized_to_pixel_polygon(polygon, image_width, image_height)
            x1, y1, x2, y2 = _bbox(pixel_polygon)
            draw.rounded_rectangle(
                (x1, y1, x2, y2),
                radius=10,
                fill=(91, 124, 111, 150),
                outline=(28, 38, 35, 230),
                width=3,
            )
            label = str(product.get("role") or product.get("name") or "item")
            draw.text(
                (x1 + 8, y1 + 8),
                label[:28],
                fill=(255, 255, 255, 255),
                font=_font(),
            )
        else:
            logger.warning(
                "product_image_missing_skipping_overlay",
                product_id=str(product.get("product_id", "")),
                role=product.get("role"),
                image_path=product.get("image_path"),
            )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_path)
    return output_relative_path, output_path


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _render_furniture_with_perspective(
    *,
    canvas: Image.Image,
    furniture: Image.Image,
    center_x_norm: float,
    floor_y_norm: float,
    placement_x_px: float,
    placement_y_px: float,
    image_width: int,
    image_height: int,
    settings,
    product: dict,
) -> None:
    """Scale, shadow, optionally skew, and composite one furniture piece."""
    original_w, original_h = furniture.size
    aspect_ratio = original_w / max(original_h, 1)

    # ---- 1. Perspective-aware scaling -----------------------------------
    # Lower normalized_y (top of image) = far away = smaller furniture.
    # Higher normalized_y (bottom of image) = close = larger furniture.
    scale = compute_perspective_scale(
        floor_y_norm,
        min_scale=settings.perspective_min_scale,
        max_scale=settings.perspective_max_scale,
    )

    target_w, target_h = compute_furniture_dimensions(
        scale,
        settings.default_furniture_width,
        aspect_ratio,
    )

    furniture_resized = furniture.resize(
        (target_w, target_h), Image.Resampling.LANCZOS
    )

    # ---- 2. Optional perspective skew -----------------------------------
    if settings.enable_perspective_skew:
        furniture_resized = apply_perspective_skew(
            furniture_resized,
            center_x_norm,
            max_skew_pixels=settings.perspective_max_skew,
        )
        # Dimensions may change slightly after skew.
        target_w, target_h = furniture_resized.size

    # ---- 3. Bottom-center anchoring -------------------------------------
    paste_x, paste_y = anchor_bottom_center(
        placement_x_px,
        placement_y_px,
        target_w,
        target_h,
        image_width,
        image_height,
    )

    # ---- 4. Shadow rendering (placed *behind* the furniture) ------------
    shadow = generate_shadow(
        furniture_resized,
        opacity=settings.shadow_opacity,
        blur_radius=settings.shadow_blur_radius,
        y_offset=settings.shadow_y_offset,
    )
    shadow_x = paste_x
    shadow_y = paste_y  # shadow is already offset internally by y_offset
    # Clamp shadow paste so it doesn't exceed canvas.
    shadow_x = max(0, min(shadow_x, image_width - shadow.width))
    shadow_y = max(0, min(shadow_y, image_height - shadow.height))
    canvas.alpha_composite(shadow, (shadow_x, shadow_y))

    # ---- 5. Paste furniture on top --------------------------------------
    canvas.alpha_composite(furniture_resized, (paste_x, paste_y))

    # ---- 6. Structured logging ------------------------------------------
    logger.info(
        "furniture_composited_perspective",
        product_id=str(product.get("product_id", "")),
        role=product.get("role"),
        original_furniture_size={"w": original_w, "h": original_h},
        final_furniture_size={"w": target_w, "h": target_h},
        perspective_scale=round(scale, 4),
        normalized_placement={"x": round(center_x_norm, 4), "y": round(floor_y_norm, 4)},
        pixel_placement={"x": round(placement_x_px, 1), "y": round(placement_y_px, 1)},
        paste_top_left={"x": paste_x, "y": paste_y},
        shadow_settings={
            "opacity": settings.shadow_opacity,
            "blur_radius": settings.shadow_blur_radius,
            "y_offset": settings.shadow_y_offset,
        },
        skew_enabled=settings.enable_perspective_skew,
    )


def _load_product_image_raw(
    storage: LocalImageStorage,
    image_path: str | None,
) -> Image.Image | None:
    """Load a product image as RGBA without resizing.

    Supports both local files and remote URLs.  Remote images are downloaded
    and cached under the product image directory so subsequent renders are fast.
    Returns *None* when the image is unavailable or corrupt, which signals
    the caller to use the rectangle fallback.
    """
    if not image_path:
        return None

    # Remote URL — download with caching for speed on subsequent renders.
    if image_path.startswith(("http://", "https://")):
        return _download_and_cache(storage, image_path)

    # Local file — try multiple candidate paths and apply background removal.
    try:
        for path in _candidate_product_paths(storage, image_path):
            if not path.exists():
                continue
            with Image.open(path) as image:
                return _prepare_product_cutout(image)
    except Exception as exc:
        logger.warning("product_image_load_failed", image_path=image_path, error=str(exc))
    return None


def _candidate_product_paths(storage: LocalImageStorage, image_path: str) -> list[Path]:
    candidates = [storage.resolve_product_image(image_path)]
    settings = storage.settings
    relative = Path(image_path)
    if not relative.is_absolute() and ".." not in relative.parts:
        candidates.append((settings.local_image_root / relative).resolve())
        candidates.append((settings.product_embedding_image_root / relative).resolve())
    return list(dict.fromkeys(candidates))


def _prepare_product_cutout(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getextrema() != (255, 255):
        return rgba.copy()

    background = _background_color_from_corners(rgba)
    if background is None:
        return rgba.copy()

    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            red, green, blue, current_alpha = pixels[x, y]
            if max(
                abs(red - background[0]),
                abs(green - background[1]),
                abs(blue - background[2]),
            ) <= 24:
                pixels[x, y] = (red, green, blue, 0)
            else:
                pixels[x, y] = (red, green, blue, current_alpha)
    return rgba


def _background_color_from_corners(image: Image.Image) -> tuple[int, int, int] | None:
    width, height = image.size
    if width == 0 or height == 0:
        return None
    corners = [
        image.getpixel((0, 0))[:3],
        image.getpixel((width - 1, 0))[:3],
        image.getpixel((0, height - 1))[:3],
        image.getpixel((width - 1, height - 1))[:3],
    ]
    average = tuple(
        int(sum(color[index] for color in corners) / len(corners))
        for index in range(3)
    )
    if min(average) < 210:
        return None
    return average


def _download_and_cache(
    storage: LocalImageStorage,
    url: str,
) -> Image.Image | None:
    """Download a remote image URL and cache it locally.

    Returns the image as RGBA or None on any failure.
    """
    import hashlib
    import io
    import requests as req_lib

    # Deterministic cache filename based on URL hash.
    url_hash = hashlib.sha256(url.encode()).hexdigest()[:16]
    ext = ".jpg"
    for candidate in (".png", ".webp", ".jpg", ".jpeg"):
        if candidate in url.lower():
            ext = candidate
            break
    cache_relative = f"cache/{url_hash}{ext}"
    cache_path = storage.resolve_product_image(cache_relative)

    # Return cached version if available.
    if cache_path.exists():
        try:
            with Image.open(cache_path) as img:
                return img.convert("RGBA").copy()
        except Exception:
            cache_path.unlink(missing_ok=True)

    # Download with timeout.
    try:
        resp = req_lib.get(url, timeout=15, stream=True)
        if resp.status_code != 200:
            logger.warning("product_image_download_failed", url=url[:120], status=resp.status_code)
            return None
        data = resp.content
        if len(data) < 100:
            return None
    except Exception as exc:
        logger.warning("product_image_download_error", url=url[:120], error=str(exc)[:200])
        return None

    # Save to cache and return.
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_bytes(data)
        with Image.open(io.BytesIO(data)) as img:
            return img.convert("RGBA").copy()
    except Exception as exc:
        logger.warning("product_image_decode_error", url=url[:120], error=str(exc)[:200])
        cache_path.unlink(missing_ok=True)
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

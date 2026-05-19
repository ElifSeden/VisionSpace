from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image

from app.core.config import Settings
from app.storage.local_storage import LocalImageStorage
from app.utils.composite import render_placeholder_composite
from app.utils.placement import (
    build_floor_placements,
    draw_placement_debug_image,
    normalized_to_pixel_polygon,
    pixel_to_normalized_polygon,
    point_inside_floor,
    polygon_center,
    validate_placement_polygon,
)


def test_placement_prompt_requires_object_and_normalized_coordinates() -> None:
    prompt = Path("app/ai/prompts/placement_plan.md").read_text()

    assert 'top-level JSON object MUST be exactly: {"placements": [...]}' in prompt
    assert "Do NOT return a bare array" in prompt
    assert 'Use "target_polygon" only' in prompt
    assert "normalized floats from 0.0 to 1.0" in prompt
    assert "Never return pixel coordinates" in prompt


def test_product_placement_rejects_pixel_coordinates() -> None:
    from pydantic import ValidationError

    from app.schemas.ai_outputs import ProductPlacement

    with pytest.raises(ValidationError, match="normalized 0.0-1.0"):
        ProductPlacement.model_validate(
            {
                "product_id": "00000000-0000-0000-0000-000000000000",
                "role": "sofa",
                "target_polygon": [[18.0, 195.0], [710.0, 195.0], [710.0, 735.0], [18.0, 735.0]],
                "confidence": 0.8,
            }
        )


def test_product_placement_accepts_normalized_coordinates() -> None:
    from app.schemas.ai_outputs import ProductPlacement

    placement = ProductPlacement.model_validate(
        {
            "product_id": "00000000-0000-0000-0000-000000000000",
            "role": "sofa",
            "target_polygon": [[0.18, 0.55], [0.72, 0.55], [0.72, 0.88], [0.18, 0.88]],
            "confidence": 0.8,
        }
    )

    assert placement.target_polygon[0] == [0.18, 0.55]


def test_coordinate_conversion_round_trips_sample_room_image(tmp_path: Path) -> None:
    _write_image(tmp_path / "sample-room-1.png", size=(1000, 500))
    polygon = [[250, 300], [750, 300], [750, 450], [250, 450]]

    normalized = pixel_to_normalized_polygon(polygon, 1000, 500)
    assert normalized == [[0.25, 0.6], [0.75, 0.6], [0.75, 0.9], [0.25, 0.9]]
    assert normalized_to_pixel_polygon(normalized, 1000, 500) == polygon


def test_build_floor_placements_rejects_invalid_points_and_accepts_floor_points(
    tmp_path: Path,
) -> None:
    _write_image(tmp_path / "sample-room-2.png", size=(1200, 800))
    products = [
        {"product_id": "p1", "role": "coffee_table"},
        {"product_id": "p2", "role": "floor_lamp"},
    ]
    room_analysis = {
        "available_placement_zones": [
            {
                "label": "central_floor",
                "polygon": [[0.0, 0.55], [1.0, 0.55], [1.0, 1.0], [0.0, 1.0]],
            }
        ],
        "existing_furniture": [
            {"label": "sofa", "polygon": [[0.24, 0.62], [0.42, 0.62], [0.42, 0.80], [0.24, 0.80]]}
        ],
    }

    placements, debug = build_floor_placements(products, 1200, 800, room_analysis)

    assert len(placements) == 2
    assert debug["rejected"]
    assert debug["rejected"][0]["reasons"] == ["overlaps_existing_furniture"]
    for placement in placements:
        center = polygon_center(placement["target_polygon"])
        assert point_inside_floor(center, debug["floor_polygon"])


def test_invalid_placement_points_are_rejected() -> None:
    floor = [[0.0, 0.50], [1.0, 0.50], [1.0, 1.0], [0.0, 1.0]]

    valid, reasons = validate_placement_polygon(
        [[0.20, 0.10], [0.40, 0.10], [0.40, 0.30], [0.20, 0.30]],
        floor,
    )

    assert not valid
    assert "center_not_on_floor" in reasons


def test_plan_placements_tolerates_settings_without_debug_flag(tmp_path: Path) -> None:
    from app.workflow.nodes.plan_placements import _validated_floor_placements

    settings = SimpleNamespace(
        local_image_root=tmp_path / "images",
        room_upload_dir=tmp_path / "images" / "rooms",
        product_image_dir=tmp_path / "images" / "products",
        generated_image_dir=tmp_path / "images" / "generated",
    )
    state = {
        "job_id": "legacy-settings",
        "room_image_path": "",
        "selected_products": [{"product_id": "p1", "role": "coffee_table"}],
        "room_analysis": {
            "available_placement_zones": [
                {
                    "label": "floor",
                    "polygon": [
                        [0.0, 0.55],
                        [1.0, 0.55],
                        [1.0, 1.0],
                        [0.0, 1.0],
                    ],
                }
            ]
        },
    }

    result = _validated_floor_placements(state, settings)

    assert result["placement_plan"]["placements"]
    assert result["placement_debug"].get("debug_image_path") is None


def test_attach_placements_drops_products_without_polygons() -> None:
    from app.workflow.nodes.plan_placements import _attach_placements_to_products

    selected = [
        {"product_id": "placed", "role": "coffee_table", "design_index": 0},
        {"product_id": "missing", "role": "floor_lamp", "design_index": 0},
    ]
    placement_map = {
        "placed": {
            "product_id": "placed",
            "target_polygon": [
                [0.2, 0.6],
                [0.4, 0.6],
                [0.4, 0.8],
                [0.2, 0.8],
            ],
        }
    }

    placed_products, dropped_products = _attach_placements_to_products(
        selected,
        placement_map,
    )

    assert placed_products == [
        {
            "product_id": "placed",
            "role": "coffee_table",
            "design_index": 0,
            "polygon": [
                [0.2, 0.6],
                [0.4, 0.6],
                [0.4, 0.8],
                [0.2, 0.8],
            ],
            "scale": 1.0,
            "rotation": 0.0,
        }
    ]
    assert dropped_products == [
        {"product_id": "missing", "role": "floor_lamp", "design_index": 0}
    ]


def test_plan_placements_drops_products_without_valid_floor_placement(tmp_path: Path) -> None:
    from app.workflow.nodes.plan_placements import _validated_floor_placements

    settings = SimpleNamespace(
        local_image_root=tmp_path / "images",
        room_upload_dir=tmp_path / "images" / "rooms",
        product_image_dir=tmp_path / "images" / "products",
        generated_image_dir=tmp_path / "images" / "generated",
    )
    state = {
        "job_id": "blocked-floor",
        "room_image_path": "",
        "selected_products": [
            {"product_id": "p1", "role": "coffee_table", "design_index": 0}
        ],
        "room_analysis": {
            "available_placement_zones": [
                {
                    "label": "floor",
                    "polygon": [
                        [0.0, 0.55],
                        [1.0, 0.55],
                        [1.0, 1.0],
                        [0.0, 1.0],
                    ],
                }
            ],
            "existing_furniture": [
                {
                    "label": "blocked_floor",
                    "polygon": [
                        [0.0, 0.45],
                        [1.0, 0.45],
                        [1.0, 1.0],
                        [0.0, 1.0],
                    ],
                }
            ],
        },
    }

    result = _validated_floor_placements(state, settings)

    assert result["placement_plan"]["placements"] == []
    assert result["selected_products"] == []
    assert result["placement_debug"]["dropped_products"] == [
        {"product_id": "p1", "role": "coffee_table", "design_index": 0}
    ]


def test_debug_image_and_placeholder_composite_are_written_for_sample_room(tmp_path: Path) -> None:
    settings = Settings(
        local_image_root=tmp_path / "images",
        room_upload_dir=tmp_path / "images" / "rooms",
        product_image_dir=tmp_path / "images" / "products",
        generated_image_dir=tmp_path / "images" / "generated",
    )
    storage = LocalImageStorage(settings)
    room_path = storage.resolve_room_image("rooms/sample-room-3.png")
    product_path = storage.resolve_product_image("products/chair.png")
    _write_image(room_path, size=(640, 480), color=(245, 241, 234))
    _write_image(product_path, size=(80, 80), color=(90, 130, 110))

    products = [
        {
            "product_id": "p1",
            "role": "armchair",
            "image_path": "products/chair.png",
            "polygon": [[0.35, 0.55], [0.55, 0.55], [0.55, 0.85], [0.35, 0.85]],
        }
    ]
    debug = {
        "image_width": 640,
        "image_height": 480,
        "floor_polygon": [[0, 0.5], [1, 0.5], [1, 1], [0, 1]],
        "accepted": [{"target_polygon": products[0]["polygon"]}],
        "rejected": [],
    }
    debug_path = storage.resolve_generated_image("generated/debug/sample-placement.png")
    draw_placement_debug_image(room_path, debug_path, debug)
    relative_path, composite_path = render_placeholder_composite(
        storage=storage,
        room_image_path="rooms/sample-room-3.png",
        products=products,
        output_relative_path="generated/sample-composite.png",
    )

    assert debug_path.exists()
    assert relative_path == "generated/sample-composite.png"
    assert composite_path.exists()
    with Image.open(composite_path) as composite:
        assert composite.size == (640, 480)
        # Sprint 2: furniture is perspective-scaled and bottom-center anchored.
        # The composite should differ from the blank room somewhere in the
        # placement region (normalized polygon spans 0.35–0.55 x, 0.55–0.85 y).
        # Check a pixel near the bottom-center anchor area.
        center_x = int(0.45 * 640)  # ~288
        floor_y = int(0.85 * 480)   # ~408  — bottom of polygon
        # The furniture or its shadow should have altered at least one nearby pixel.
        region_changed = False
        for dy in range(-40, 10):
            px = composite.getpixel((center_x, max(0, min(floor_y + dy, 479))))
            if px != (245, 241, 234):
                region_changed = True
                break
        assert region_changed, "Composite should differ from blank room in the placement region"


def test_composite_output_with_transparent_furniture(tmp_path: Path) -> None:
    """Verify composite file is created with a transparent-background furniture PNG."""
    settings = Settings(
        local_image_root=tmp_path / "images",
        room_upload_dir=tmp_path / "images" / "rooms",
        product_image_dir=tmp_path / "images" / "products",
        generated_image_dir=tmp_path / "images" / "generated",
    )
    storage = LocalImageStorage(settings)
    room_path = storage.resolve_room_image("rooms/test-room.png")
    product_path = storage.resolve_product_image("products/lamp.png")

    # Room: solid color.
    _write_image(room_path, size=(800, 600), color=(230, 225, 215))
    # Furniture: RGBA with partial transparency (simulates a real product cutout).
    product_path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGBA", (60, 120), (200, 180, 160, 200)).save(product_path)

    products = [
        {
            "product_id": "p2",
            "role": "floor_lamp",
            "image_path": "products/lamp.png",
            "polygon": [[0.40, 0.50], [0.52, 0.50], [0.52, 0.90], [0.40, 0.90]],
        }
    ]
    relative_path, composite_path = render_placeholder_composite(
        storage=storage,
        room_image_path="rooms/test-room.png",
        products=products,
        output_relative_path="generated/test-composite.png",
    )
    assert composite_path.exists()
    with Image.open(composite_path) as img:
        assert img.size == (800, 600)


def _write_image(
    path: Path,
    size: tuple[int, int],
    color: tuple[int, int, int] = (200, 200, 200),
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", size, color).save(path)


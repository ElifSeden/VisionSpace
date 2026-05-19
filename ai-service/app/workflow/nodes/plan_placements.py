"""Plan placements — Sprint 4 layout planner integration.

Uses the new LayoutPlanner for intelligent multi-furniture placement.
Falls back to the original Sprint 1 ``build_floor_placements`` if the
planner fails or produces no valid placements.
"""

import json
import structlog
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.ai.vertex_client import VertexAIClient, load_prompt
from app.schemas.ai_outputs import PlacementPlan
from app.storage.local_storage import LocalImageStorage
from app.utils.placement import (
    build_floor_placements,
    draw_placement_debug_image,
    image_size,
    normalize_polygon,
)
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState

logger = structlog.get_logger(__name__)


def plan_placements_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "plan_placements")
        settings = get_settings()
        selected = state.get("selected_products", [])

        if not selected:
            return {"placement_plan": {"placements": []}, "selected_products": []}

        # Sprint 4: try the layout planner first, fall back to Sprint 1 logic.
        try:
            result = _layout_planner_placements(state, settings)
            if result and result.get("selected_products"):
                # Check that at least one product got a polygon.
                has_placements = any(
                    p.get("polygon") for p in result["selected_products"]
                )
                if has_placements:
                    logger.info(
                        "plan_placements_layout_planner_used",
                        job_id=state.get("job_id"),
                        num_placed=sum(1 for p in result["selected_products"] if p.get("polygon")),
                    )
                    return result
        except Exception as exc:
            logger.warning(
                "layout_planner_failed_falling_back",
                job_id=state.get("job_id"),
                error=str(exc),
            )

        # Fallback: original Sprint 1 placement logic.
        logger.info("plan_placements_fallback_to_sprint1", job_id=state.get("job_id"))
        return _validated_floor_placements(state, settings)

    return node


def _layout_planner_placements(state: DesignWorkflowState, settings) -> dict | None:
    """Use Gemini RAG 3.1 Pro for intelligent placement."""
    selected = state.get("selected_products", [])
    room_analysis = state.get("room_analysis", {})
    storage = LocalImageStorage(settings)
    room_image_path = state.get("room_image_path", "")
    resolved_room = storage.resolve_room_image(room_image_path) if room_image_path else None
    image_width, image_height = image_size(resolved_room) if resolved_room else (1280, 720)

    # Extract floor polygon from room analysis.
    floor_polygon = _floor_polygon_from_analysis(room_analysis, image_width, image_height)
    
    products_to_place = []
    for p in selected:
        product_minimal = {
            "product_id": str(p.get("product_id")),
            "role": p.get("role"),
            "category": p.get("category"),
            "name": p.get("name"),
            "dimensions": p.get("metadata", {}).get("dimensions", {}),
        }
        products_to_place.append(product_minimal)
        
    client = VertexAIClient(settings)
    prompt_template = load_prompt("placement_plan.md")
    prompt = (
        f"{prompt_template}\n\n"
        f"Room analysis:\n{json.dumps(room_analysis, indent=2)}\n\n"
        f"Products to place:\n{json.dumps(products_to_place, indent=2)}\n\n"
        f"Image dimensions: {image_width}x{image_height} pixels\n"
        f"Coordinate system required in output: normalized_0_1\n"
        f"Floor polygon, normalized_0_1: {json.dumps(floor_polygon)}\n"
    )

    try:
        plan = client.generate_json(
            prompt=prompt,
            response_schema=PlacementPlan,
            images=[resolved_room] if resolved_room else None,
            model_tier="pro",  # Gemini 3.1 Pro for spatial reasoning
        )
    except Exception as exc:
        logger.warning("gemini_placement_failed", error=str(exc))
        return None

    if not plan or not plan.placements:
        return None

    placements = []
    placement_map = {}

    for pp in plan.placements:
        placement = {
            "product_id": pp.product_id,
            "role": pp.role,
            "placement_type": "new",
            "target_polygon": pp.target_polygon,
            "depth_order": pp.depth_order,
            "confidence": pp.confidence,
            "notes": pp.notes,
            "scale": pp.scale,
            "rotation": pp.rotation,
        }
        placements.append(placement)
        placement_map[str(pp.product_id)] = placement

    placed_products, dropped_products = _attach_placements_to_products(
        selected,
        placement_map,
    )

    debug = {
        "coordinate_system": "normalized_0_1",
        "image_width": image_width,
        "image_height": image_height,
        "floor_polygon": floor_polygon,
        "existing_furniture": [],
        "accepted": placements,
        "rejected": [],
        "planner": "gemini_rag_v1",
    }
    if dropped_products:
        debug["dropped_products"] = dropped_products

    # Debug output.
    debug_placement_enabled = bool(getattr(settings, "debug_placement", False))
    if debug_placement_enabled and resolved_room is not None:
        debug_image_path = f"generated/debug/{state['job_id']}_placement.png"
        output_path = storage.resolve_generated_image(debug_image_path)
        draw_placement_debug_image(resolved_room, output_path, debug)
        debug["debug_image_path"] = debug_image_path

    logger.info(
        "plan_placements_layout_planner",
        job_id=state.get("job_id"),
        placed=len(placed_products),
        dropped=len(dropped_products),
    )

    return {
        "placement_plan": {"placements": placements, "debug": debug},
        "placement_debug": debug,
        "selected_products": placed_products,
    }


def _validated_floor_placements(state: DesignWorkflowState, settings) -> dict:
    """Original Sprint 1 fallback placement logic."""
    selected = state.get("selected_products", [])
    storage = LocalImageStorage(settings)
    room_image_path = state.get("room_image_path", "")
    resolved_room = storage.resolve_room_image(room_image_path) if room_image_path else None
    image_width, image_height = image_size(resolved_room) if resolved_room else (1280, 720)

    placements, debug = build_floor_placements(
        selected,
        image_width=image_width,
        image_height=image_height,
        room_analysis=state.get("room_analysis"),
    )
    placement_map = {str(placement["product_id"]): placement for placement in placements}
    placed_products, dropped_products = _attach_placements_to_products(
        selected,
        placement_map,
    )
    if dropped_products:
        debug["dropped_products"] = dropped_products

    debug_image_path = None
    debug_placement_enabled = bool(getattr(settings, "debug_placement", False))
    if debug_placement_enabled and resolved_room is not None:
        debug_image_path = f"generated/debug/{state['job_id']}_placement.png"
        output_path = storage.resolve_generated_image(debug_image_path)
        draw_placement_debug_image(resolved_room, output_path, debug)
        debug["debug_image_path"] = debug_image_path

    logger.info(
        "plan_placements_validated",
        job_id=state.get("job_id"),
        original_image_size={"width": image_width, "height": image_height},
        coordinate_system="normalized_0_1",
        accepted_count=len(debug["accepted"]),
        rejected_count=len(debug["rejected"]),
        dropped_count=len(dropped_products),
        debug_image_path=debug_image_path,
    )

    return {
        "placement_plan": {"placements": placements, "debug": debug},
        "placement_debug": debug,
        "selected_products": placed_products,
    }


def _attach_placements_to_products(
    selected: list[dict],
    placement_map: dict[str, dict],
) -> tuple[list[dict], list[dict]]:
    placed_products = []
    dropped_products = []
    for product in selected:
        placement = placement_map.get(str(product.get("product_id")))
        if placement:
            product["polygon"] = placement["target_polygon"]
            product["scale"] = placement.get("scale", 1.0)
            product["rotation"] = placement.get("rotation", 0.0)
            placed_products.append(product)
        else:
            dropped_products.append(
                {
                    "product_id": product.get("product_id"),
                    "role": product.get("role"),
                    "design_index": product.get("design_index"),
                }
            )
    return placed_products, dropped_products


def _floor_polygon_from_analysis(
    room_analysis: dict,
    image_width: int,
    image_height: int,
) -> list[list[float]]:
    """Extract normalized floor polygon from room analysis."""
    zones = room_analysis.get("available_placement_zones") or []
    for zone in zones:
        label = str(zone.get("label") or "").lower()
        if "floor" in label and zone.get("polygon"):
            return normalize_polygon(zone["polygon"], image_width, image_height)
    return [[0.0, 0.5], [1.0, 0.5], [1.0, 1.0], [0.0, 1.0]]

import structlog
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.storage.local_storage import LocalImageStorage
from app.utils.placement import build_floor_placements, draw_placement_debug_image, image_size
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

        return _validated_floor_placements(state, settings)

    return node


def _validated_floor_placements(state: DesignWorkflowState, settings) -> dict:
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
    for product in selected:
        placement = placement_map.get(str(product["product_id"]))
        if placement:
            product["polygon"] = placement["target_polygon"]

    debug_image_path = None
    if settings.debug_placement and resolved_room is not None:
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
        debug_image_path=debug_image_path,
    )

    return {
        "placement_plan": {"placements": placements, "debug": debug},
        "placement_debug": debug,
        "selected_products": selected,
    }

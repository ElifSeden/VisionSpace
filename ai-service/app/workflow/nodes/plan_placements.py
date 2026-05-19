from sqlalchemy.orm import Session

from app.utils.geometry import clamp_polygon_to_image
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def _polygon_for(index: int) -> list[list[float]]:
    width = 1280
    height = 720
    x = 220 + (index % 3) * 260
    y = 430 + (index // 3) * 90
    return clamp_polygon_to_image([[x, y], [x + 220, y], [x + 240, y + 120], [x - 20, y + 120]], width, height)


def plan_placements_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "plan_placements")
        placements = []
        counters: dict[int, int] = {}
        for product in state.get("selected_products", []):
            design_index = int(product["design_index"])
            slot = counters.get(design_index, 0)
            counters[design_index] = slot + 1
            polygon = _polygon_for(slot)
            product["polygon"] = polygon
            placements.append(
                {
                    "product_id": product["product_id"],
                    "role": product["role"],
                    "placement_type": "new",
                    "target_polygon": polygon,
                    "depth_order": slot,
                    "confidence": 0.6,
                }
            )
        return {"placement_plan": {"placements": placements}, "selected_products": state.get("selected_products", [])}

    return node


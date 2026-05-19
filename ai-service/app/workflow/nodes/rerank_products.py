from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def rerank_products_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "rerank_products")
        max_selected = get_settings().max_selected_per_design
        selected = []
        used_products = set()
        for strategy in state.get("design_strategies", []):
            design_products = []
            for role in strategy["furniture_roles"]:
                key = f"{strategy['design_index']}:{role}"
                candidates = sorted(state.get("candidate_products", {}).get(key, []), key=lambda c: c["score"], reverse=True)
                candidate = next((c for c in candidates if c["product_id"] not in used_products), candidates[0] if candidates else None)
                if not candidate:
                    continue
                used_products.add(candidate["product_id"])
                design_products.append(
                    {
                        **candidate,
                        "design_index": strategy["design_index"],
                        "role": role,
                        "reason": "Selected by deterministic category, style, color, material, and fit scoring.",
                    }
                )
                if len(design_products) >= max_selected:
                    break
            selected.extend(design_products)
        return {"selected_products": selected}

    return node


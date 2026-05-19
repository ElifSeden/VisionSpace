from sqlalchemy.orm import Session

from app.schemas.ai_outputs import ProductRetrievalIntent
from app.vector.product_search import search_products
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def retrieve_candidates_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "retrieve_candidates")
        prefs = state.get("user_preferences", {})
        room_analysis = state.get("room_analysis", {})
        candidate_products: dict[str, list[dict]] = {}
        intents = []
        for strategy in state.get("design_strategies", []):
            for role in strategy["furniture_roles"]:
                intent = ProductRetrievalIntent(
                    role=role,
                    category=role,
                    styles=[prefs["design_style"]] if prefs.get("design_style") else [],
                    material=[prefs["material"]] if prefs.get("material") else [],
                    colors=prefs.get("colors") or [],
                    temperature=prefs.get("temperature"),
                    room_types=[room_analysis.get("room_type", "living_room")],
                    query_text=f"{strategy.get('style', '')} {role} {prefs.get('extra_preferences') or ''}".strip(),
                )
                key = f"{strategy['design_index']}:{role}"
                intents.append(intent.model_dump())
                candidate_products[key] = [c.model_dump(mode="json") for c in search_products(db, intent)]
        return {"retrieval_intents": intents, "candidate_products": candidate_products}

    return node


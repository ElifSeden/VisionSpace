from sqlalchemy.orm import Session

from app.schemas.ai_outputs import DesignStrategy
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


DEFAULT_ROLES = ["coffee_table", "carpet", "floor_lamp"]


def create_design_strategies_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "create_design_strategies")
        prefs = state.get("user_preferences", {})
        roles = prefs.get("requested_furniture_types") or DEFAULT_ROLES
        count = int(state.get("requested_design_count") or 1)
        strategies = []
        for index in range(1, count + 1):
            strategy = DesignStrategy(
                design_index=index,
                title=f"{(prefs.get('design_style') or 'Balanced').title()} Design {index}",
                style=prefs.get("design_style") or "balanced",
                furniture_roles=roles,
                notes=prefs.get("extra_preferences"),
            )
            strategies.append(strategy.model_dump())
        return {"design_strategies": strategies}

    return node


from sqlalchemy.orm import Session

from app.core.errors import PlacementValidationError
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def validate_result_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "validate_result")
        for product in state.get("selected_products", []):
            if not product.get("product_id") or not product.get("role") or not product.get("polygon"):
                raise PlacementValidationError("Selected product is missing required placement fields")
        return {}

    return node


from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def generate_images_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "generate_images")
        if not get_settings().enable_image_generation:
            return {"generated_images": []}
        return {"generated_images": []}

    return node


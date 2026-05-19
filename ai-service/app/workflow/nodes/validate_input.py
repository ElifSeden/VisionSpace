from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import ValidationStageError
from app.db.repositories.design_job_repository import DesignJobRepository
from app.storage.local_storage import LocalImageStorage
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def validate_input_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "validate_input")
        job = DesignJobRepository(db).get(state["job_id"])
        if not job:
            raise ValidationStageError("Design job not found")
        if not LocalImageStorage().room_image_exists(state["room_image_path"]):
            raise ValidationStageError("Room image does not exist")
        count = max(1, min(
            int(state.get("requested_design_count") or get_settings().default_design_count),
            get_settings().default_design_count,
        ))
        return {"requested_design_count": count}

    return node


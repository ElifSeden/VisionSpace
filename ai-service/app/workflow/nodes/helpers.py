from sqlalchemy.orm import Session

from app.db.repositories.design_job_repository import DesignJobRepository
from app.workflow.state import DesignWorkflowState


def progress(db: Session, state: DesignWorkflowState, stage: str) -> None:
    state["current_stage"] = stage
    DesignJobRepository(db).update_workflow_state(state["job_id"], dict(state))


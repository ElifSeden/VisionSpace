from uuid import UUID

from app.db.repositories.design_job_repository import DesignJobRepository
from app.db.session import new_session
from app.workflow.graph import run_design_workflow


def run_design_job(job_id: str) -> None:
    with new_session() as db:
        job = DesignJobRepository(db).get(UUID(job_id))
        if not job:
            raise RuntimeError(f"Design job not found: {job_id}")
        state = {
            "job_id": str(job.id),
            "room_image_path": job.input_room_image_path,
            "room_dimensions": job.room_dimensions,
            "user_preferences": job.user_preferences,
            "requested_design_count": job.requested_design_count,
            "errors": [],
        }
        run_design_workflow(db, state)

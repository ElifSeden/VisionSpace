from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.constants import JOB_STATUS_COMPLETED, JOB_STATUS_FAILED
from app.db.models.design_job import DesignJob
from app.db.models.generated_design import GeneratedDesign
from app.db.models.product import Product
from app.db.models.selected_product import SelectedProduct


class DesignJobRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, room_image_path: str, room_dimensions: dict, preferences: dict, requested_design_count: int) -> DesignJob:
        job = DesignJob(
            input_room_image_path=room_image_path,
            room_dimensions=room_dimensions,
            user_preferences=preferences,
            replace_existing_furniture=bool(preferences.get("replace_existing_furniture", False)),
            requested_design_count=requested_design_count,
            workflow_state={"current_stage": "queued"},
        )
        self.db.add(job)
        self.db.commit()
        self.db.refresh(job)
        return job

    def get(self, job_id: UUID) -> DesignJob | None:
        return self.db.get(DesignJob, job_id)

    def get_with_results(self, job_id: UUID) -> DesignJob | None:
        stmt = (
            select(DesignJob)
            .where(DesignJob.id == job_id)
            .options(
                selectinload(DesignJob.designs)
                .selectinload(GeneratedDesign.selected_products)
                .selectinload(SelectedProduct.product)
                .selectinload(Product.images)
            )
        )
        return self.db.scalar(stmt)

    def update_status(self, job: DesignJob, status: str, error_message: str | None = None) -> None:
        job.status = status
        job.error_message = error_message
        if status in {JOB_STATUS_COMPLETED, JOB_STATUS_FAILED}:
            job.completed_at = datetime.now(UTC)
        self.db.commit()

    def update_workflow_state(self, job_id: str | UUID, state: dict) -> None:
        job = self.db.get(DesignJob, UUID(str(job_id)))
        if job:
            job.workflow_state = state
            self.db.commit()

    def persist_results(self, job: DesignJob, final_designs: list[dict], room_analysis: dict | None) -> None:
        job.designs.clear()
        self.db.flush()
        for design in final_designs:
            generated = GeneratedDesign(
                design_job_id=job.id,
                design_index=design["design_index"],
                title=design.get("title"),
                style=design.get("style"),
                summary=design.get("summary"),
                generated_image_path=design.get("generated_image_path"),
                room_analysis=room_analysis,
                placement_plan={"placements": design.get("products", [])},
                confidence=design.get("confidence") or {},
            )
            self.db.add(generated)
            self.db.flush()
            for product in design.get("products", []):
                self.db.add(
                    SelectedProduct(
                        generated_design_id=generated.id,
                        product_id=UUID(str(product["product_id"])),
                        role=product["role"],
                        reason=product.get("reason"),
                        polygon=product.get("polygon"),
                        score=product.get("score"),
                        meta=product.get("metadata") or {},
                    )
                )
        job.status = JOB_STATUS_COMPLETED
        job.completed_at = datetime.now(UTC)
        self.db.commit()

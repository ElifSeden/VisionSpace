from uuid import UUID

from typing import Any

from sqlalchemy.orm import Session

from app.core.constants import JOB_STATUS_COMPLETED
from app.db.models.design_job import DesignJob
from app.db.repositories.design_job_repository import DesignJobRepository
from app.schemas.design_job import (
    ClickableRegion,
    CreateDesignJobRequest,
    DesignJobOut,
    DesignOut,
    ProductCard,
)
from app.utils.store_names import normalize_store_name_from_url


class DesignService:
    def __init__(self, db: Session, queue: Any | None = None):
        self.db = db
        self.repo = DesignJobRepository(db)
        self.queue = queue

    def create_job(self, request: CreateDesignJobRequest) -> DesignJob:
        job = self.repo.create(
            room_image_path=request.room_image_path,
            room_dimensions=request.room_dimensions.model_dump(),
            preferences=request.preferences.model_dump(),
            requested_design_count=request.requested_design_count,
        )
        if self.queue is None:
            from app.workers.rq_worker import get_queue

            queue = get_queue()
        else:
            queue = self.queue
        from app.workers.jobs import run_design_job

        queue.enqueue(run_design_job, str(job.id), job_timeout="30m")
        return job

    def get_job(self, job_id: UUID) -> DesignJobOut | None:
        job = self.repo.get_with_results(job_id)
        if not job:
            return None
        progress = None if job.status == JOB_STATUS_COMPLETED else job.workflow_state
        return DesignJobOut(
            job_id=job.id,
            status=job.status,
            progress=progress,
            error_message=job.error_message,
            designs=[self._design_out(design) for design in job.designs],
        )

    def _design_out(self, design) -> DesignOut:
        regions = []
        products = []
        for selected in design.selected_products:
            product = selected.product
            primary = next(
                (img for img in product.images if img.is_primary),
                product.images[0] if product.images else None,
            )
            store_name = normalize_store_name_from_url(product.source_url)
            if selected.polygon:
                regions.append(
                    ClickableRegion(
                        region_id=selected.id,
                        polygon=selected.polygon,
                        product_id=product.id,
                    )
                )
            products.append(
                ProductCard(
                    product_id=product.id,
                    external_id=product.external_id,
                    name=product.name,
                    category=product.category,
                    brand=store_name,
                    store_name=store_name,
                    role=selected.role,
                    source_url=product.source_url,
                    image_path=primary.relative_path if primary else None,
                    price={
                        "amount": float(product.price_amount),
                        "currency": product.price_currency,
                    }
                    if product.price_amount is not None
                    else None,
                    reason=selected.reason,
                    score=float(selected.score) if selected.score is not None else None,
                )
            )
        placement_debug = (
            (design.placement_plan or {}).get("debug") if design.placement_plan else None
        )
        image_payload = None
        if design.generated_image_path:
            image_payload = {
                "path": design.generated_image_path,
                "width": placement_debug.get("image_width") if placement_debug else None,
                "height": placement_debug.get("image_height") if placement_debug else None,
            }
        return DesignOut(
            design_id=design.id,
            title=design.title,
            style=design.style,
            summary=design.summary,
            image=image_payload,
            placement_debug=placement_debug,
            clickable_regions=regions,
            products=products,
        )

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.design_job import CreateDesignJobRequest, CreateDesignJobResponse, DesignJobOut
from app.services.design_service import DesignService

router = APIRouter(prefix="/design-jobs", tags=["design-jobs"])


@router.post("", response_model=CreateDesignJobResponse)
def create_design_job(request: CreateDesignJobRequest, db: Session = Depends(get_db)) -> CreateDesignJobResponse:
    job = DesignService(db).create_job(request)
    return CreateDesignJobResponse(job_id=job.id, status=job.status)


@router.get("/{job_id}", response_model=DesignJobOut)
def get_design_job(job_id: UUID, db: Session = Depends(get_db)) -> DesignJobOut:
    result = DesignService(db).get_job(job_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Design job not found")
    return result


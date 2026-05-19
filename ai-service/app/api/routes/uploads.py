from fastapi import APIRouter, File, HTTPException, UploadFile

from app.core.errors import ImageStorageError
from app.schemas.design_job import UploadRoomImageResponse
from app.services.upload_service import UploadService

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/room-image", response_model=UploadRoomImageResponse)
async def upload_room_image(file: UploadFile = File(...)) -> UploadRoomImageResponse:
    try:
        image_path, width, height = await UploadService().save_room_image(file)
    except ImageStorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return UploadRoomImageResponse(image_path=image_path, width=width, height=height)


from fastapi import UploadFile

from app.storage.local_storage import LocalImageStorage


class UploadService:
    def __init__(self):
        self.storage = LocalImageStorage()

    async def save_room_image(self, file: UploadFile) -> tuple[str, int, int]:
        return await self.storage.save_room_upload(file)


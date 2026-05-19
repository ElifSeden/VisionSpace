import uuid
from datetime import UTC, datetime
from pathlib import Path

from fastapi import UploadFile
from PIL import Image

from app.core.config import Settings, get_settings
from app.core.errors import ImageStorageError


ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


class LocalImageStorage:
    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()

    def _safe_relative(self, relative_path: str) -> Path:
        path = Path(relative_path)
        if path.is_absolute() or ".." in path.parts:
            raise ImageStorageError("Invalid image path")
        return path

    def _resolve_under_root_or_dir(self, relative_path: str, prefix: str, directory: Path) -> Path:
        path = self._safe_relative(relative_path)
        if path.parts and path.parts[0] == prefix:
            return (self.settings.local_image_root / path).resolve()
        return (directory / path).resolve()

    def resolve_room_image(self, relative_path: str) -> Path:
        return self._resolve_under_root_or_dir(relative_path, "rooms", self.settings.room_upload_dir)

    def resolve_product_image(self, relative_path: str) -> Path:
        return self._resolve_under_root_or_dir(relative_path, "products", self.settings.product_image_dir)

    def resolve_generated_image(self, relative_path: str) -> Path:
        return self._resolve_under_root_or_dir(relative_path, "generated", self.settings.generated_image_dir)

    def room_image_exists(self, relative_path: str) -> bool:
        return self.resolve_room_image(relative_path).exists()

    async def save_room_upload(self, file: UploadFile) -> tuple[str, int, int]:
        if file.content_type not in ALLOWED_CONTENT_TYPES:
            raise ImageStorageError("Unsupported image content type")
        ext = Path(file.filename or "").suffix.lower()
        if ext not in ALLOWED_IMAGE_EXTENSIONS:
            raise ImageStorageError("Unsupported image extension")

        max_bytes = self.settings.max_upload_mb * 1024 * 1024
        data = await file.read(max_bytes + 1)
        if len(data) > max_bytes:
            raise ImageStorageError("Upload exceeds size limit")

        now = datetime.now(UTC)
        dated_relative = Path(str(now.year)) / f"{now.month:02d}" / f"{uuid.uuid4().hex}{ext}"
        absolute = self.settings.room_upload_dir / dated_relative
        try:
            relative = absolute.resolve().relative_to(self.settings.local_image_root.resolve())
        except ValueError:
            relative = dated_relative
        absolute.parent.mkdir(parents=True, exist_ok=True)
        absolute.write_bytes(data)

        try:
            with Image.open(absolute) as image:
                image.verify()
            with Image.open(absolute) as image:
                width, height = image.size
        except Exception as exc:
            absolute.unlink(missing_ok=True)
            raise ImageStorageError("Invalid image file") from exc

        return relative.as_posix(), width, height

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.constants import JOB_STATUS_QUEUED
from app.db.session import Base


class DesignJob(Base):
    __tablename__ = "design_jobs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    status: Mapped[str] = mapped_column(Text, nullable=False, default=JOB_STATUS_QUEUED, index=True)
    input_room_image_path: Mapped[str] = mapped_column(Text, nullable=False)
    room_dimensions: Mapped[dict] = mapped_column(JSONB, nullable=False)
    user_preferences: Mapped[dict] = mapped_column(JSONB, nullable=False)
    replace_existing_furniture: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    requested_design_count: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    workflow_state: Mapped[dict | None] = mapped_column(JSONB)
    error_message: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    designs = relationship("GeneratedDesign", back_populates="design_job", cascade="all, delete-orphan")


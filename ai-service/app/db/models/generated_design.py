import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class GeneratedDesign(Base):
    __tablename__ = "generated_designs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    design_job_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("design_jobs.id", ondelete="CASCADE"))
    design_index: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str | None] = mapped_column(Text)
    style: Mapped[str | None] = mapped_column(Text)
    summary: Mapped[str | None] = mapped_column(Text)
    generated_image_path: Mapped[str | None] = mapped_column(Text)
    room_analysis: Mapped[dict | None] = mapped_column(JSONB)
    placement_plan: Mapped[dict | None] = mapped_column(JSONB)
    confidence: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    design_job = relationship("DesignJob", back_populates="designs")
    selected_products = relationship("SelectedProduct", back_populates="generated_design", cascade="all, delete-orphan")


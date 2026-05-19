import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Numeric, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Product(Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    external_id: Mapped[str] = mapped_column(Text, unique=True, nullable=False, index=True)
    source: Mapped[str | None] = mapped_column(Text)
    source_url: Mapped[str | None] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(Text, nullable=False, index=True)
    price_amount: Mapped[float | None] = mapped_column(Numeric)
    price_currency: Mapped[str | None] = mapped_column(Text)
    width_cm: Mapped[float | None] = mapped_column(Numeric)
    depth_cm: Mapped[float | None] = mapped_column(Numeric)
    height_cm: Mapped[float | None] = mapped_column(Numeric)
    material: Mapped[list[str] | None] = mapped_column(ARRAY(Text))
    colors: Mapped[list[str] | None] = mapped_column(ARRAY(Text))
    styles: Mapped[list[str] | None] = mapped_column(ARRAY(Text))
    temperature: Mapped[str | None] = mapped_column(Text)
    room_types: Mapped[list[str] | None] = mapped_column(ARRAY(Text))
    is_group: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    group_items: Mapped[dict | list | None] = mapped_column(JSONB)
    raw_metadata: Mapped[dict | None] = mapped_column(JSONB)
    enriched_metadata: Mapped[dict | None] = mapped_column(JSONB)
    metadata_confidence: Mapped[dict | None] = mapped_column(JSONB)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    images = relationship("ProductImage", back_populates="product", cascade="all, delete-orphan")


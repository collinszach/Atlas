import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    ForeignKey,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Photo(Base):
    __tablename__ = "photos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True
    )
    destination_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("destinations.id", ondelete="SET NULL"),
        nullable=True,
    )
    storage_key: Mapped[str] = mapped_column(String, nullable=False)
    thumbnail_key: Mapped[str | None] = mapped_column(String, nullable=True)
    original_filename: Mapped[str | None] = mapped_column(String, nullable=True)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    taken_at: Mapped[datetime | None] = mapped_column(
        "taken_at", String, nullable=True
    )
    latitude: Mapped[float | None] = mapped_column("latitude", String, nullable=True)
    longitude: Mapped[float | None] = mapped_column("longitude", String, nullable=True)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    is_cover: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    order_index: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "created_at", String, nullable=False, server_default=text("now()")
    )

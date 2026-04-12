import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, SmallInteger, Text, DateTime, ForeignKey, Numeric, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class BucketList(Base):
    __tablename__ = "bucket_list"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                           server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"),
                                          nullable=False, index=True)
    country_code: Mapped[str | None] = mapped_column(String(2), nullable=True)
    country_name: Mapped[str | None] = mapped_column(String, nullable=True)
    city: Mapped[str | None] = mapped_column(String, nullable=True)
    priority: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="3")
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    ideal_season: Mapped[str | None] = mapped_column(String, nullable=True)
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    trip_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True),
                                                       ForeignKey("trips.id", ondelete="SET NULL"),
                                                       nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

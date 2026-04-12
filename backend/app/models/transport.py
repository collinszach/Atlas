import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, Integer, Text, Numeric, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from geoalchemy2 import Geography
from geoalchemy2.types import WKBElement

from app.database import Base


class TransportLeg(Base):
    __tablename__ = "transport_legs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String, nullable=False, server_default="flight")

    # Flight-specific
    flight_number: Mapped[str | None] = mapped_column(String, nullable=True)
    airline: Mapped[str | None] = mapped_column(String, nullable=True)
    origin_iata: Mapped[str | None] = mapped_column(String(3), nullable=True)
    dest_iata: Mapped[str | None] = mapped_column(String(3), nullable=True)
    origin_city: Mapped[str | None] = mapped_column(String, nullable=True)
    dest_city: Mapped[str | None] = mapped_column(String, nullable=True)

    # Timing + logistics
    departure_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    arrival_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    seat_class: Mapped[str | None] = mapped_column(String, nullable=True)
    booking_ref: Mapped[str | None] = mapped_column(String, nullable=True)
    cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), server_default="USD")
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Geo
    origin_geo: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)
    dest_geo: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

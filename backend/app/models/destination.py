import uuid
from datetime import datetime, date
from sqlalchemy import String, DateTime, Date, Integer, SmallInteger, Text, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates
from geoalchemy2 import Geography
from geoalchemy2.types import WKBElement

from app.database import Base


class Destination(Base):
    __tablename__ = "destinations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String, nullable=False)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    country_name: Mapped[str] = mapped_column(String, nullable=False)
    region: Mapped[str | None] = mapped_column(String, nullable=True)
    location: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)
    arrival_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    departure_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # nights: plain writable Integer, NOT a DB-generated column.
    # Intentional deviation from the design spec's GENERATED ALWAYS AS clause.
    # The @validates hook below computes this in Python at assignment time.
    # See backend plan: "nights (Integer nullable — computed in Python)".
    nights: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    @validates("arrival_date", "departure_date")
    def _compute_nights(self, key, value):
        arrival = value if key == "arrival_date" else self.arrival_date
        departure = value if key == "departure_date" else self.departure_date
        if arrival is not None and departure is not None:
            self.nights = (departure - arrival).days
        return value

    trip: Mapped["Trip"] = relationship("Trip", back_populates="destinations")

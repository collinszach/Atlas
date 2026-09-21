import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Device(Base):
    __tablename__ = "skywatch_devices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                           server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"),
                                          nullable=False, index=True)
    apns_token: Mapped[str | None] = mapped_column(String, nullable=True)
    platform: Mapped[str] = mapped_column(String, nullable=False, server_default="ios")
    last_lat: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    last_lng: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    push_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SkywatchPreference(Base):
    __tablename__ = "skywatch_preferences"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                           server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"),
                                          nullable=False, unique=True, index=True)

    # Trigger toggles
    notable_types_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    military_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    emergency_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    watchlist_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))

    radius_km: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False, server_default="30")
    alt_ceiling_ft: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cooldown_minutes: Mapped[int] = mapped_column(Integer, nullable=False, server_default="360")

    quiet_hours: Mapped[dict[str, Any]] = mapped_column(JSONB, server_default=text("'{}'"))
    watchlist: Mapped[list[Any]] = mapped_column(JSONB, server_default=text("'[]'"))
    nl_prompt: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(),
                                                   onupdate=func.now())


class AircraftAlert(Base):
    __tablename__ = "aircraft_alerts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                           server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"),
                                          nullable=False, index=True)

    hex: Mapped[str] = mapped_column(String(6), nullable=False, index=True)
    callsign: Mapped[str | None] = mapped_column(String, nullable=True)
    type: Mapped[str | None] = mapped_column(String, nullable=True)
    registration: Mapped[str | None] = mapped_column(String, nullable=True)

    trigger: Mapped[str] = mapped_column(String, nullable=False)
    score: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    message: Mapped[str | None] = mapped_column(Text, nullable=True)

    lat: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    lng: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    alt_baro: Mapped[int | None] = mapped_column(Integer, nullable=True)
    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)

    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Engagement feedback. Both null means the alert was neither opened nor
    # explicitly dismissed — absence of signal, not a negative signal.
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    dismissed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class NotableType(Base):
    __tablename__ = "notable_types"

    type_code: Mapped[str] = mapped_column(String(10), primary_key=True)
    description: Mapped[str] = mapped_column(String, nullable=False)
    rarity_tier: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="1")


class MilCallsignPrefix(Base):
    __tablename__ = "mil_callsign_prefixes"

    prefix: Mapped[str] = mapped_column(String(10), primary_key=True)
    description: Mapped[str] = mapped_column(String, nullable=False)


class AircraftTrack(Base):
    """One observation of one aircraft at one instant.

    Deliberately **not** user-scoped, unlike every other Atlas table. These are
    public ADS-B broadcasts, not personal data, and they are deduplicated across
    users who observe the same aircraft in the same cycle. Recording which user's
    poll produced an observation would turn a table of public aircraft positions
    into a location history of the user, which is exactly what we don't want.
    Precedent: `notable_types` and `mil_callsign_prefixes` are global too.
    """

    __tablename__ = "aircraft_tracks"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)

    hex: Mapped[str] = mapped_column(String(6), nullable=False)
    # Quantized to the start of the watch cycle so concurrent observers collapse
    # to one row via the (hex, seen_at) unique constraint.
    seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    callsign: Mapped[str | None] = mapped_column(String, nullable=True)
    registration: Mapped[str | None] = mapped_column(String, nullable=True)
    type: Mapped[str | None] = mapped_column(String, nullable=True)

    lat: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    lng: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    alt_baro: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ground_speed: Mapped[Decimal | None] = mapped_column(Numeric(7, 2), nullable=True)
    track_deg: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    squawk: Mapped[str | None] = mapped_column(String(4), nullable=True)
    is_military: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))

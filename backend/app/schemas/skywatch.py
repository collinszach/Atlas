from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any
from pydantic import BaseModel, model_validator

_VALID_PLATFORMS = {"ios", "android"}


# --- Devices ---

class DeviceCreate(BaseModel):
    apns_token: str | None = None
    platform: str = "ios"
    push_enabled: bool = True

    @model_validator(mode="after")
    def validate_platform(self) -> "DeviceCreate":
        if self.platform not in _VALID_PLATFORMS:
            raise ValueError(f"platform must be one of {sorted(_VALID_PLATFORMS)}")
        return self


class DeviceRead(BaseModel):
    id: uuid.UUID
    user_id: str
    apns_token: str | None
    platform: str
    last_lat: Decimal | None
    last_lng: Decimal | None
    last_seen: datetime | None
    push_enabled: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Location ---

class LocationUpdate(BaseModel):
    device_id: uuid.UUID | None = None
    lat: float
    lng: float

    @model_validator(mode="after")
    def validate_coords(self) -> "LocationUpdate":
        if not (-90.0 <= self.lat <= 90.0):
            raise ValueError("lat must be between -90 and 90")
        if not (-180.0 <= self.lng <= 180.0):
            raise ValueError("lng must be between -180 and 180")
        return self


# --- Preferences ---

class SkywatchPreferenceUpdate(BaseModel):
    notable_types_enabled: bool | None = None
    military_enabled: bool | None = None
    emergency_enabled: bool | None = None
    watchlist_enabled: bool | None = None
    radius_km: Decimal | None = None
    alt_ceiling_ft: int | None = None
    cooldown_minutes: int | None = None
    quiet_hours: dict[str, Any] | None = None
    watchlist: list[Any] | None = None
    nl_prompt: str | None = None

    @model_validator(mode="after")
    def validate_fields(self) -> "SkywatchPreferenceUpdate":
        if self.radius_km is not None and not (0 < self.radius_km <= Decimal("463")):
            # 250nm in km, matches airplanes.live max radius
            raise ValueError("radius_km must be between 0 and 463 (250nm)")
        if self.alt_ceiling_ft is not None and self.alt_ceiling_ft < 0:
            raise ValueError("alt_ceiling_ft must be non-negative")
        if self.cooldown_minutes is not None and self.cooldown_minutes < 0:
            raise ValueError("cooldown_minutes must be non-negative")
        return self


# --- Natural-language preference compilation ---

class PreferencesFromText(BaseModel):
    text: str

    @model_validator(mode="after")
    def validate_text(self) -> "PreferencesFromText":
        if not self.text.strip():
            raise ValueError("text must not be empty")
        return self


class SkywatchPreferenceRead(BaseModel):
    id: uuid.UUID
    user_id: str
    notable_types_enabled: bool
    military_enabled: bool
    emergency_enabled: bool
    watchlist_enabled: bool
    radius_km: Decimal
    alt_ceiling_ft: int | None
    cooldown_minutes: int
    quiet_hours: dict[str, Any]
    watchlist: list[Any]
    nl_prompt: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Overhead aircraft ---

class AircraftMatch(BaseModel):
    trigger: str
    score: int
    message: str


class OverheadAircraft(BaseModel):
    hex: str
    flight: str | None = None
    registration: str | None = None
    type: str | None = None
    lat: float | None = None
    lon: float | None = None
    alt_baro: int | None = None
    ground_speed: float | None = None
    track: float | None = None
    squawk: str | None = None
    is_military: bool = False
    distance_km: float | None = None
    matches: list[AircraftMatch] = []


class OverheadResponse(BaseModel):
    aircraft: list[OverheadAircraft]
    source: str


# --- Alerts ---

class AircraftAlertRead(BaseModel):
    id: uuid.UUID
    user_id: str
    hex: str
    callsign: str | None
    type: str | None
    registration: str | None
    trigger: str
    score: int
    message: str | None
    lat: Decimal | None
    lng: Decimal | None
    alt_baro: int | None
    distance_km: Decimal | None
    sent_at: datetime

    model_config = {"from_attributes": True}

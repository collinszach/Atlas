from __future__ import annotations
from typing import Any
from pydantic import BaseModel


class Aircraft(BaseModel):
    """Normalized ADS-B target, parsed from airplanes.live / dump1090 `ac` entries."""

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

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "Aircraft":
        """Parse a single entry from the airplanes.live / dump1090 `ac` array."""
        hex_code = raw.get("hex")
        if not hex_code:
            raise ValueError("Aircraft entry missing required 'hex' field")

        db_flags = raw.get("dbFlags") or 0
        alt_baro = raw.get("alt_baro")
        # "ground" is a valid alt_baro value for landed aircraft
        if isinstance(alt_baro, str):
            alt_baro = 0 if alt_baro == "ground" else None

        flight = raw.get("flight")
        if isinstance(flight, str):
            flight = flight.strip() or None

        return cls(
            hex=str(hex_code).lower(),
            flight=flight,
            registration=raw.get("r"),
            type=raw.get("t"),
            lat=raw.get("lat"),
            lon=raw.get("lon"),
            alt_baro=alt_baro,
            ground_speed=raw.get("gs"),
            track=raw.get("track"),
            squawk=raw.get("squawk"),
            is_military=bool(int(db_flags) & 1),
        )

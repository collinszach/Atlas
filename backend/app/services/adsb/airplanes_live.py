from __future__ import annotations
import logging

import httpx

from app.config import settings
from app.services.adsb.geo import haversine_km, km_to_nm
from app.services.adsb.models import Aircraft

logger = logging.getLogger(__name__)

MAX_RADIUS_NM = 250


class AdsbServiceError(Exception):
    """Raised when an ADS-B data source cannot be reached or returns invalid data."""


class AirplanesLiveClient:
    """Async client for the free, keyless airplanes.live REST API."""

    def __init__(self, base_url: str | None = None, timeout: float = 10.0) -> None:
        self._base_url = (base_url or settings.airplanes_live_base).rstrip("/")
        self._timeout = timeout

    async def get_point(self, lat: float, lon: float, radius_km: float) -> list[Aircraft]:
        """Fetch aircraft within `radius_km` of (lat, lon).

        Raises AdsbServiceError on network failure, HTTP error, or malformed response.
        """
        radius_nm = min(km_to_nm(radius_km), MAX_RADIUS_NM)
        url = f"{self._base_url}/point/{lat}/{lon}/{radius_nm:.2f}"

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(url)
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise AdsbServiceError(f"airplanes.live request failed: {exc}") from exc
        except ValueError as exc:
            raise AdsbServiceError(f"airplanes.live returned invalid JSON: {exc}") from exc

        raw_ac = data.get("ac")
        if raw_ac is None:
            raise AdsbServiceError("airplanes.live response missing 'ac' field")

        aircraft: list[Aircraft] = []
        for raw in raw_ac:
            try:
                ac = Aircraft.from_raw(raw)
            except ValueError as exc:
                logger.warning("Skipping malformed aircraft entry: %s", exc)
                continue
            if ac.lat is not None and ac.lon is not None:
                ac.distance_km = haversine_km(lat, lon, ac.lat, ac.lon)
            aircraft.append(ac)
        return aircraft

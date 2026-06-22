from __future__ import annotations
import logging

import httpx

from app.config import settings
from app.services.adsb.airplanes_live import AdsbServiceError
from app.services.adsb.geo import haversine_km
from app.services.adsb.models import Aircraft

logger = logging.getLogger(__name__)


class LocalDump1090Client:
    """Async client for a local dump1090/readsb `aircraft.json` endpoint.

    The URL is expected to be reachable over Tailscale (e.g. the home NUC
    receiver). If `dump1090_url` is not configured, callers should skip this
    client entirely — `get_aircraft` raises AdsbServiceError if called without
    a configured URL.
    """

    def __init__(self, url: str | None = None, timeout: float = 5.0) -> None:
        self._url = url if url is not None else settings.dump1090_url
        self._timeout = timeout

    @property
    def is_configured(self) -> bool:
        return bool(self._url)

    async def get_aircraft(self, lat: float | None = None, lon: float | None = None) -> list[Aircraft]:
        """Fetch all aircraft currently visible to the local receiver.

        Raises AdsbServiceError if no URL is configured or the request fails.
        """
        if not self._url:
            raise AdsbServiceError("dump1090_url is not configured")

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(self._url)
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise AdsbServiceError(f"dump1090 request failed: {exc}") from exc
        except ValueError as exc:
            raise AdsbServiceError(f"dump1090 returned invalid JSON: {exc}") from exc

        raw_ac = data.get("aircraft", data.get("ac", []))

        aircraft: list[Aircraft] = []
        for raw in raw_ac:
            try:
                ac = Aircraft.from_raw(raw)
            except ValueError as exc:
                logger.warning("Skipping malformed aircraft entry: %s", exc)
                continue
            if lat is not None and lon is not None and ac.lat is not None and ac.lon is not None:
                ac.distance_km = haversine_km(lat, lon, ac.lat, ac.lon)
            aircraft.append(ac)
        return aircraft

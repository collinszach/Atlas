from __future__ import annotations
import logging

from app.services.adsb.airplanes_live import AirplanesLiveClient, AdsbServiceError
from app.services.adsb.dump1090 import LocalDump1090Client
from app.services.adsb.models import Aircraft

logger = logging.getLogger(__name__)


class DataSourceResolver:
    """Merges aircraft from the local receiver and airplanes.live, deduped by hex.

    Local-receiver data is preferred when both sources report the same hex.
    If no local URL is configured, only the network source is queried.
    """

    def __init__(
        self,
        network_client: AirplanesLiveClient | None = None,
        local_client: LocalDump1090Client | None = None,
    ) -> None:
        self._network = network_client or AirplanesLiveClient()
        self._local = local_client or LocalDump1090Client()

    async def get_aircraft(self, lat: float, lon: float, radius_km: float) -> list[Aircraft]:
        """Return aircraft within `radius_km` of (lat, lon), merged and deduped by hex.

        Raises AdsbServiceError only if the network source fails — local data is
        best-effort and silently skipped on failure.
        """
        network_aircraft = await self._network.get_point(lat, lon, radius_km)
        merged: dict[str, Aircraft] = {ac.hex: ac for ac in network_aircraft}

        if self._local.is_configured:
            try:
                local_aircraft = await self._local.get_aircraft(lat, lon)
            except AdsbServiceError as exc:
                logger.warning("Local ADS-B receiver unavailable, using network only: %s", exc)
            else:
                for ac in local_aircraft:
                    if ac.distance_km is not None and ac.distance_km > radius_km:
                        continue
                    merged[ac.hex] = ac  # local preferred — overwrites network entry

        return list(merged.values())

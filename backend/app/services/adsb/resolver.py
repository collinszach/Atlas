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

    @property
    def has_local_source(self) -> bool:
        return self._local.is_configured

    async def get_aircraft(self, lat: float, lon: float, radius_km: float) -> list[Aircraft]:
        """Return aircraft within `radius_km` of (lat, lon), merged and deduped by hex.

        Either source alone is enough. Raises AdsbServiceError only when every
        configured source fails — a local receiver is the whole point of owning
        one, so a gated or rate-limited network source must not take the sky
        down with it.
        """
        merged: dict[str, Aircraft] = {}
        network_error: AdsbServiceError | None = None

        try:
            for ac in await self._network.get_point(lat, lon, radius_km):
                merged[ac.hex] = ac
        except AdsbServiceError as exc:
            network_error = exc
            if not self._local.is_configured:
                raise
            logger.warning("Network ADS-B source unavailable, using local only: %s", exc)

        local_error: AdsbServiceError | None = None
        if self._local.is_configured:
            try:
                local_aircraft = await self._local.get_aircraft(lat, lon)
            except AdsbServiceError as exc:
                local_error = exc
                logger.warning("Local ADS-B receiver unavailable: %s", exc)
            else:
                for ac in local_aircraft:
                    if ac.distance_km is not None and ac.distance_km > radius_km:
                        continue
                    merged[ac.hex] = ac  # local preferred — overwrites network entry

        if network_error is not None and local_error is not None:
            raise AdsbServiceError(
                f"all ADS-B sources failed (network: {network_error}; local: {local_error})"
            )

        return list(merged.values())

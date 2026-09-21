"""A local receiver must keep working when the network source is gated.

airplanes.live now returns 403 without manual project approval. The resolver
previously queried the network source first and raised on its failure, so a
gated network source took the whole sky down even with a healthy dump1090 —
which defeats the point of owning a receiver.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock

from app.services.adsb.airplanes_live import AdsbServiceError
from app.services.adsb.models import Aircraft
from app.services.adsb.resolver import DataSourceResolver


def _network(aircraft=None, error=None):
    client = MagicMock()
    client.get_point = AsyncMock(side_effect=error) if error else AsyncMock(return_value=aircraft or [])
    return client


def _local(aircraft=None, error=None, configured=True):
    client = MagicMock()
    client.is_configured = configured
    client.get_aircraft = AsyncMock(side_effect=error) if error else AsyncMock(return_value=aircraft or [])
    return client


@pytest.mark.asyncio
async def test_local_data_survives_a_gated_network_source():
    resolver = DataSourceResolver(
        network_client=_network(error=AdsbServiceError("403 Forbidden")),
        local_client=_local([Aircraft(hex="abc123", lat=37.7, lon=-122.4, distance_km=5.0)]),
    )
    result = await resolver.get_aircraft(37.7, -122.4, 30)
    assert [ac.hex for ac in result] == ["abc123"]


@pytest.mark.asyncio
async def test_network_failure_still_raises_without_a_local_receiver():
    resolver = DataSourceResolver(
        network_client=_network(error=AdsbServiceError("403 Forbidden")),
        local_client=_local(configured=False),
    )
    with pytest.raises(AdsbServiceError):
        await resolver.get_aircraft(37.7, -122.4, 30)


@pytest.mark.asyncio
async def test_raises_only_when_every_source_fails():
    resolver = DataSourceResolver(
        network_client=_network(error=AdsbServiceError("403")),
        local_client=_local(error=AdsbServiceError("connection refused")),
    )
    with pytest.raises(AdsbServiceError) as exc:
        await resolver.get_aircraft(37.7, -122.4, 30)
    assert "all ADS-B sources failed" in str(exc.value)


@pytest.mark.asyncio
async def test_network_only_still_works():
    resolver = DataSourceResolver(
        network_client=_network([Aircraft(hex="def456", lat=37.7, lon=-122.4)]),
        local_client=_local(configured=False),
    )
    result = await resolver.get_aircraft(37.7, -122.4, 30)
    assert [ac.hex for ac in result] == ["def456"]


@pytest.mark.asyncio
async def test_local_wins_on_hex_collision():
    """Local data is first-hand; the network aggregate is seconds behind."""
    resolver = DataSourceResolver(
        network_client=_network([Aircraft(hex="abc123", lat=1.0, lon=1.0)]),
        local_client=_local([Aircraft(hex="abc123", lat=2.0, lon=2.0, distance_km=3.0)]),
    )
    result = await resolver.get_aircraft(37.7, -122.4, 30)
    assert len(result) == 1
    assert result[0].lat == 2.0


@pytest.mark.asyncio
async def test_local_contacts_beyond_the_radius_are_dropped():
    resolver = DataSourceResolver(
        network_client=_network([]),
        local_client=_local([Aircraft(hex="far001", lat=1.0, lon=1.0, distance_km=400.0)]),
    )
    result = await resolver.get_aircraft(37.7, -122.4, 30)
    assert result == []

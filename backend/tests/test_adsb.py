import pytest
import httpx

from app.services.adsb.airplanes_live import AirplanesLiveClient, AdsbServiceError, MAX_RADIUS_NM
from app.services.adsb.dump1090 import LocalDump1090Client
from app.services.adsb.geo import haversine_km, km_to_nm
from app.services.adsb.models import Aircraft
from app.services.adsb.resolver import DataSourceResolver

FAKE_AC_PAYLOAD = {
    "ac": [
        {
            "hex": "a1b2c3",
            "flight": "UAL123  ",
            "r": "N12345",
            "t": "B738",
            "lat": 37.7,
            "lon": -122.4,
            "alt_baro": 35000,
            "gs": 450.5,
            "track": 270.0,
            "squawk": "1200",
            "dbFlags": 0,
        },
        {
            "hex": "ae1234",
            "flight": "RCH123  ",
            "r": "12-3456",
            "t": "C17",
            "lat": 37.71,
            "lon": -122.41,
            "alt_baro": 28000,
            "gs": 400.0,
            "track": 90.0,
            "squawk": "1201",
            "dbFlags": 1,
        },
        {
            "hex": "deadbe",
            # malformed: missing hex would be skipped, but this one is on ground
            "flight": None,
            "r": None,
            "t": None,
            "lat": 37.72,
            "lon": -122.42,
            "alt_baro": "ground",
            "gs": 0,
            "track": None,
            "squawk": None,
            "dbFlags": 0,
        },
    ]
}


# --- Aircraft.from_raw ---

def test_aircraft_from_raw_parses_fields():
    ac = Aircraft.from_raw(FAKE_AC_PAYLOAD["ac"][0])
    assert ac.hex == "a1b2c3"
    assert ac.flight == "UAL123"
    assert ac.registration == "N12345"
    assert ac.type == "B738"
    assert ac.lat == 37.7
    assert ac.alt_baro == 35000
    assert ac.is_military is False


def test_aircraft_from_raw_military_flag():
    ac = Aircraft.from_raw(FAKE_AC_PAYLOAD["ac"][1])
    assert ac.is_military is True
    assert ac.flight == "RCH123"


def test_aircraft_from_raw_ground_altitude():
    ac = Aircraft.from_raw(FAKE_AC_PAYLOAD["ac"][2])
    assert ac.alt_baro == 0
    assert ac.flight is None


def test_aircraft_from_raw_requires_hex():
    with pytest.raises(ValueError):
        Aircraft.from_raw({"flight": "UAL123"})


# --- haversine / unit conversions ---

def test_haversine_zero_distance():
    assert haversine_km(37.0, -122.0, 37.0, -122.0) == 0.0


def test_haversine_known_distance():
    # SF to LA roughly 559 km
    d = haversine_km(37.7749, -122.4194, 34.0522, -118.2437)
    assert 550 < d < 570


def test_km_to_nm():
    assert km_to_nm(1.852) == pytest.approx(1.0)


# --- AirplanesLiveClient ---

@pytest.mark.asyncio
async def test_airplanes_live_get_point_parses_response():
    def handler(request: httpx.Request) -> httpx.Response:
        assert "/point/37.7/-122.4/" in request.url.path
        return httpx.Response(200, json=FAKE_AC_PAYLOAD)

    transport = httpx.MockTransport(handler)
    client = AirplanesLiveClient()

    async def fake_get_point(lat, lon, radius_km):
        async with httpx.AsyncClient(transport=transport, base_url=client._base_url) as http_client:
            radius_nm = min(km_to_nm(radius_km), MAX_RADIUS_NM)
            resp = await http_client.get(f"/point/{lat}/{lon}/{radius_nm:.2f}")
            resp.raise_for_status()
            data = resp.json()
        aircraft = [Aircraft.from_raw(raw) for raw in data["ac"]]
        return aircraft

    aircraft = await fake_get_point(37.7, -122.4, 30.0)
    assert len(aircraft) == 3
    hexes = {ac.hex for ac in aircraft}
    assert "a1b2c3" in hexes
    assert "ae1234" in hexes


@pytest.mark.asyncio
async def test_airplanes_live_get_point_real_client(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=FAKE_AC_PAYLOAD)

    transport = httpx.MockTransport(handler)

    class FakeAsyncClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    client = AirplanesLiveClient()
    aircraft = await client.get_point(37.7, -122.4, 30.0)

    assert len(aircraft) == 3
    military = [a for a in aircraft if a.is_military]
    assert len(military) == 1
    assert military[0].hex == "ae1234"
    # distance_km should be computed since lat/lon present
    assert all(a.distance_km is not None for a in aircraft)


@pytest.mark.asyncio
async def test_airplanes_live_raises_on_http_error(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    transport = httpx.MockTransport(handler)

    class FakeAsyncClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    client = AirplanesLiveClient()
    with pytest.raises(AdsbServiceError):
        await client.get_point(37.7, -122.4, 30.0)


@pytest.mark.asyncio
async def test_airplanes_live_raises_on_missing_ac_field(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"msg": "no data"})

    transport = httpx.MockTransport(handler)

    class FakeAsyncClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    client = AirplanesLiveClient()
    with pytest.raises(AdsbServiceError):
        await client.get_point(37.7, -122.4, 30.0)


# --- LocalDump1090Client ---

@pytest.mark.asyncio
async def test_local_dump1090_not_configured_raises():
    client = LocalDump1090Client(url="")
    assert client.is_configured is False
    with pytest.raises(AdsbServiceError):
        await client.get_aircraft(37.7, -122.4)


@pytest.mark.asyncio
async def test_local_dump1090_parses_aircraft_json(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"aircraft": FAKE_AC_PAYLOAD["ac"]})

    transport = httpx.MockTransport(handler)

    class FakeAsyncClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    client = LocalDump1090Client(url="http://nuc.local:8080/data/aircraft.json")
    assert client.is_configured is True
    aircraft = await client.get_aircraft(37.7, -122.4)
    assert len(aircraft) == 3


# --- DataSourceResolver ---

@pytest.mark.asyncio
async def test_resolver_network_only_when_no_local():
    class FakeNetworkClient:
        async def get_point(self, lat, lon, radius_km):
            return [Aircraft(hex="aaaaaa", flight="ABC123")]

    local = LocalDump1090Client(url="")
    resolver = DataSourceResolver(network_client=FakeNetworkClient(), local_client=local)
    assert resolver.has_local_source is False

    aircraft = await resolver.get_aircraft(37.7, -122.4, 30.0)
    assert len(aircraft) == 1
    assert aircraft[0].hex == "aaaaaa"


@pytest.mark.asyncio
async def test_resolver_prefers_local_on_shared_hex():
    class FakeNetworkClient:
        async def get_point(self, lat, lon, radius_km):
            return [
                Aircraft(hex="aaaaaa", flight="NETWORK", distance_km=10.0),
                Aircraft(hex="bbbbbb", flight="NETONLY", distance_km=5.0),
            ]

    class FakeLocalClient:
        is_configured = True

        async def get_aircraft(self, lat, lon):
            return [Aircraft(hex="aaaaaa", flight="LOCAL", distance_km=1.0)]

    resolver = DataSourceResolver(network_client=FakeNetworkClient(), local_client=FakeLocalClient())
    aircraft = await resolver.get_aircraft(37.7, -122.4, 30.0)

    by_hex = {a.hex: a for a in aircraft}
    assert by_hex["aaaaaa"].flight == "LOCAL"
    assert by_hex["bbbbbb"].flight == "NETONLY"


@pytest.mark.asyncio
async def test_resolver_falls_back_when_local_fails():
    from app.services.adsb.airplanes_live import AdsbServiceError as _Err

    class FakeNetworkClient:
        async def get_point(self, lat, lon, radius_km):
            return [Aircraft(hex="aaaaaa", flight="NETWORK")]

    class FakeLocalClient:
        is_configured = True

        async def get_aircraft(self, lat, lon):
            raise _Err("receiver offline")

    resolver = DataSourceResolver(network_client=FakeNetworkClient(), local_client=FakeLocalClient())
    aircraft = await resolver.get_aircraft(37.7, -122.4, 30.0)
    assert len(aircraft) == 1
    assert aircraft[0].flight == "NETWORK"

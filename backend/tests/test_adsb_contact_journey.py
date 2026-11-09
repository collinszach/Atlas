"""Offline replay of synthetic source snapshots through the actual ADS-B clients."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import httpx
import pytest

from app.services.adsb.airplanes_live import AirplanesLiveClient, AdsbServiceError
from app.services.adsb.dump1090 import LocalDump1090Client


@pytest.fixture
def contact_frames() -> list[dict[str, Any]]:
    path = Path(__file__).parent / "fixtures" / "adsb_contact_journey.json"
    return json.loads(path.read_text())["frames"]


@pytest.fixture(params=["network", "local"])
def replay_source(request, monkeypatch):
    """Every HTTP request consumes one snapshot; unexpected requests fail locally."""
    responses: list[httpx.Response | Exception] = []
    payload_key = "ac" if request.param == "network" else "aircraft"

    def handler(http_request: httpx.Request) -> httpx.Response:
        assert http_request.url.host == "adsb.invalid"
        assert responses, "Unexpected extra ADS-B request"
        response = responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response

    transport = httpx.MockTransport(handler)
    original_client = httpx.AsyncClient

    def mock_client(*args, **kwargs):
        kwargs["transport"] = transport
        return original_client(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", mock_client)
    if request.param == "network":
        client = AirplanesLiveClient(base_url="https://adsb.invalid")

        async def fetch():
            return await client.get_point(0, 0, 30)
    else:
        client = LocalDump1090Client(url="https://adsb.invalid/aircraft.json")

        async def fetch():
            return await client.get_aircraft(0, 0)

    def enqueue(aircraft: list[dict[str, Any]]) -> None:
        responses.append(httpx.Response(200, json={payload_key: aircraft}))

    yield fetch, enqueue, responses
    assert not responses, "Replay did not consume all snapshots"


async def test_contact_journey_characterizes_current_client_behavior(
    replay_source, contact_frames
):
    fetch, enqueue, _ = replay_source
    snapshots = {}
    for frame in contact_frames:
        enqueue(frame["aircraft"])
        snapshots[frame["name"]] = await fetch()

    fresh, = snapshots["fresh"]
    stale, = snapshots["stale_position_recent_message"]
    assert fresh.hex == stale.hex == "abc001"
    assert (fresh.lat, fresh.lon) == (0.01, 0.02)
    # Characterization: clients currently discard age, so stale coordinates survive.
    assert stale.model_dump() == fresh.model_dump()
    assert stale.distance_km is not None

    missing, = snapshots["missing_position"]
    assert missing.hex == fresh.hex
    assert missing.lat is missing.lon is missing.distance_km is None
    assert snapshots["lost_contact"] == []

    reacquired, = snapshots["reacquired"]
    assert reacquired.hex == fresh.hex
    assert (reacquired.lat, reacquired.lon) == (0.03, 0.04)
    assert reacquired.distance_km > fresh.distance_km
    assert (fresh.lat, fresh.lon) == (0.01, 0.02)


@pytest.mark.parametrize("failure", ["timeout", "http_error"])
async def test_outage_is_not_an_empty_sky_and_next_poll_recovers(
    replay_source, contact_frames, failure
):
    fetch, enqueue, responses = replay_source
    enqueue(contact_frames[0]["aircraft"])
    assert len(await fetch()) == 1
    responses.append(
        httpx.ReadTimeout("synthetic receiver timeout")
        if failure == "timeout" else httpx.Response(503)
    )
    with pytest.raises(AdsbServiceError):
        await fetch()
    enqueue([])
    assert await fetch() == []
    enqueue(contact_frames[-1]["aircraft"])
    recovered, = await fetch()
    assert (recovered.hex, recovered.lat, recovered.lon) == ("abc001", 0.03, 0.04)

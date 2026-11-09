import pytest

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def auth_stats_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_empty_user(auth_stats_client):
    """New user with no data returns zeroed stats."""
    resp = await auth_stats_client.get("/api/v1/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["flights_count"] == 0
    assert body["total_distance_km"] == 0.0
    assert body["co2_kg_estimate"] == 0.0
    assert body["hours_in_air"] is None
    assert body["top_airline"] is None


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_with_data(auth_stats_client):
    """Stats aggregate correctly after logging a flight."""
    resp = await auth_stats_client.post(
        "/api/v1/flights",
        json={"distance_km": "5560", "origin_iata": "NRT", "dest_iata": "SFO"},
    )
    assert resp.status_code == 201

    resp = await auth_stats_client.get("/api/v1/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["flights_count"] == 1
    assert body["total_distance_km"] == 5560.0
    assert abs(body["co2_kg_estimate"] - 5560.0 * 0.115) < 0.01


@pytest.mark.asyncio
@pytest.mark.integration
@pytest.mark.parametrize(
    "legs,expected_distance_km,expected_hours",
    [
        ([{"distance_km": "1600", "duration_min": 90}], 1600.0, 1.5),
        ([{"distance_km": "1600"}], 1600.0, 2.0),
        ([{"distance_km": "1600", "duration_min": 0}], 1600.0, 0.0),
        ([{"duration_min": 90}], 0.0, 1.5),
        ([{}], 0.0, 0.0),
        ([{"duration_min": 4}, {"duration_min": 4}], 0.0, 0.1),
        (
            [
                {"distance_km": "111.20", "duration_min": 90},
                {"distance_km": "222.39"},
                {},
            ],
            333.59,
            1.8,
        ),
    ],
    ids=["duration-precedence", "estimated-time", "zero-duration", "duration-only",
         "unknown-time", "round-after-sum", "mixed-flights"],
)
async def test_logbook_distance_and_time_reconciliation(
    auth_stats_client, db_session, legs, expected_distance_km, expected_hours
):
    from app.models.transport import TransportLeg

    # A second synthetic user's large totals must not enter this user's stats.
    db_session.add(TransportLeg(
        user_id="user_test_other_002", distance_km=9000, duration_min=600,
    ))
    await db_session.commit()

    for leg in legs:
        response = await auth_stats_client.post("/api/v1/flights", json=leg)
        assert response.status_code == 201, response.text
        saved = response.json()
        assert saved["distance_km"] == (
            float(leg["distance_km"]) if "distance_km" in leg else None
        )
        assert saved["duration_min"] == leg.get("duration_min")

    response = await auth_stats_client.get("/api/v1/stats")
    assert response.status_code == 200, response.text
    stats = response.json()
    assert stats["flights_count"] == len(legs)
    assert stats["total_distance_km"] == pytest.approx(expected_distance_km, abs=0.001)
    assert stats["hours_in_air"] == expected_hours

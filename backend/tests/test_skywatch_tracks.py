"""Phase 0 data foundation: observation retention + alert engagement feedback."""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import delete, select, text

from app.services.adsb.models import Aircraft

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.fixture
async def clean_tracks(db_session):
    from app.models.skywatch import AircraftTrack
    yield
    await db_session.execute(delete(AircraftTrack).where(AircraftTrack.hex.like("tst%")))
    await db_session.commit()


def _ac(hex_: str, lat=37.7, lon=-122.4, **kw):
    return Aircraft(hex=hex_, lat=lat, lon=lon, **kw)


# --- cycle quantization -------------------------------------------------

def test_cycle_timestamp_is_stable_within_a_poll_interval():
    """Two observers a moment apart must agree, or dedupe can't collapse them."""
    from app.services.skywatch.tracks import cycle_timestamp

    base = datetime(2026, 9, 20, 12, 0, 3, tzinfo=timezone.utc)
    later = datetime(2026, 9, 20, 12, 0, 9, tzinfo=timezone.utc)
    assert cycle_timestamp(base) == cycle_timestamp(later)


def test_cycle_timestamp_advances_between_intervals():
    from app.services.skywatch.tracks import cycle_timestamp

    a = datetime(2026, 9, 20, 12, 0, 1, tzinfo=timezone.utc)
    b = datetime(2026, 9, 20, 12, 5, 1, tzinfo=timezone.utc)
    assert cycle_timestamp(a) < cycle_timestamp(b)


# --- recording ----------------------------------------------------------

@pytest.mark.asyncio
@pytest.mark.integration
async def test_records_one_row_per_aircraft(db_session, clean_tracks):
    from app.services.skywatch.tracks import record_observations
    from app.models.skywatch import AircraftTrack

    seen = datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc)
    written = await record_observations(
        db_session,
        [_ac("tst001", alt_baro=35000, ground_speed=450.0, track=270.0),
         _ac("tst002", alt_baro=12000)],
        seen,
    )
    await db_session.commit()
    assert written == 2

    rows = (await db_session.execute(
        select(AircraftTrack).where(AircraftTrack.hex.like("tst%"))
    )).scalars().all()
    assert {r.hex for r in rows} == {"tst001", "tst002"}


@pytest.mark.asyncio
@pytest.mark.integration
async def test_second_observer_in_same_cycle_is_deduped(db_session, clean_tracks):
    """Two devices seeing the same aircraft must not double the history."""
    from app.services.skywatch.tracks import record_observations
    from app.models.skywatch import AircraftTrack

    seen = datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc)
    await record_observations(db_session, [_ac("tst010")], seen)
    await db_session.commit()
    second = await record_observations(db_session, [_ac("tst010")], seen)
    await db_session.commit()

    assert second == 0
    count = len((await db_session.execute(
        select(AircraftTrack).where(AircraftTrack.hex == "tst010")
    )).scalars().all())
    assert count == 1


@pytest.mark.asyncio
@pytest.mark.integration
async def test_same_aircraft_in_a_later_cycle_is_a_new_point(db_session, clean_tracks):
    from app.services.skywatch.tracks import record_observations
    from app.models.skywatch import AircraftTrack

    t1 = datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc)
    t2 = t1 + timedelta(minutes=1)
    await record_observations(db_session, [_ac("tst011", lat=37.7)], t1)
    await record_observations(db_session, [_ac("tst011", lat=37.9)], t2)
    await db_session.commit()

    rows = (await db_session.execute(
        select(AircraftTrack).where(AircraftTrack.hex == "tst011").order_by(AircraftTrack.seen_at)
    )).scalars().all()
    assert len(rows) == 2
    assert float(rows[0].lat) != float(rows[1].lat)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_positionless_contacts_are_skipped(db_session, clean_tracks):
    """A row with no fix teaches nothing and would burn a dedupe slot."""
    from app.services.skywatch.tracks import record_observations

    seen = datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc)
    written = await record_observations(
        db_session, [Aircraft(hex="tst020", lat=None, lon=None)], seen
    )
    await db_session.commit()
    assert written == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_duplicate_hex_within_one_batch_collapses(db_session, clean_tracks):
    """One resolver response can merge dump1090 + network and repeat a hex."""
    from app.services.skywatch.tracks import record_observations

    seen = datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc)
    written = await record_observations(
        db_session, [_ac("tst030", lat=37.1), _ac("tst030", lat=37.2)], seen
    )
    await db_session.commit()
    assert written == 1


# --- retention ----------------------------------------------------------

@pytest.mark.asyncio
@pytest.mark.integration
async def test_prune_removes_only_expired_rows(db_session, clean_tracks):
    from app.config import settings
    from app.services.skywatch.tracks import prune_tracks, record_observations
    from app.models.skywatch import AircraftTrack

    now = datetime.now(timezone.utc)
    stale = now - timedelta(days=settings.skywatch_track_retention_days + 2)
    fresh = now - timedelta(days=1)
    await record_observations(db_session, [_ac("tst040")], stale)
    await record_observations(db_session, [_ac("tst041")], fresh)
    await db_session.commit()

    await prune_tracks(db_session, now=now)

    remaining = {r.hex for r in (await db_session.execute(
        select(AircraftTrack).where(AircraftTrack.hex.like("tst04%"))
    )).scalars().all()}
    assert remaining == {"tst041"}


# --- alert engagement (the API seam) ------------------------------------

@pytest.mark.asyncio
async def test_alert_interaction_requires_auth(client):
    resp = await client.post(
        f"/api/v1/skywatch/alerts/{uuid.uuid4()}/interaction", json={"action": "opened"}
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
@pytest.mark.integration
async def test_alert_interaction_records_opened(authed_client, db_session):
    from app.models.skywatch import AircraftAlert

    alert = AircraftAlert(user_id=TEST_USER_ID, hex="abc123", trigger="military", score=5)
    db_session.add(alert)
    await db_session.commit()
    await db_session.refresh(alert)

    resp = await authed_client.post(
        f"/api/v1/skywatch/alerts/{alert.id}/interaction", json={"action": "opened"}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["opened_at"] is not None
    assert body["dismissed_at"] is None

    await db_session.execute(delete(AircraftAlert).where(AircraftAlert.id == alert.id))
    await db_session.commit()


@pytest.mark.asyncio
@pytest.mark.integration
async def test_alert_interaction_is_idempotent(authed_client, db_session):
    """A double-tap must not overwrite the original timestamp."""
    from app.models.skywatch import AircraftAlert

    alert = AircraftAlert(user_id=TEST_USER_ID, hex="abc124", trigger="rare", score=3)
    db_session.add(alert)
    await db_session.commit()
    await db_session.refresh(alert)

    first = await authed_client.post(
        f"/api/v1/skywatch/alerts/{alert.id}/interaction", json={"action": "opened"}
    )
    second = await authed_client.post(
        f"/api/v1/skywatch/alerts/{alert.id}/interaction", json={"action": "opened"}
    )
    assert first.json()["opened_at"] == second.json()["opened_at"]

    await db_session.execute(delete(AircraftAlert).where(AircraftAlert.id == alert.id))
    await db_session.commit()


@pytest.mark.asyncio
@pytest.mark.integration
async def test_cannot_record_interaction_on_another_users_alert(authed_client, db_session):
    """User isolation is mandatory on every query, not optional."""
    from app.models.skywatch import AircraftAlert

    alert = AircraftAlert(user_id=OTHER_USER_ID, hex="abc125", trigger="military", score=5)
    db_session.add(alert)
    await db_session.commit()
    await db_session.refresh(alert)

    resp = await authed_client.post(
        f"/api/v1/skywatch/alerts/{alert.id}/interaction", json={"action": "opened"}
    )
    assert resp.status_code == 404

    await db_session.execute(delete(AircraftAlert).where(AircraftAlert.id == alert.id))
    await db_session.commit()


@pytest.mark.asyncio
@pytest.mark.integration
async def test_rejects_unknown_action(authed_client):
    resp = await authed_client.post(
        f"/api/v1/skywatch/alerts/{uuid.uuid4()}/interaction", json={"action": "ignored"}
    )
    assert resp.status_code == 422


# --- non-ICAO (TIS-B) identifiers ---------------------------------------

def test_tisb_hex_fits_the_column():
    """Feeds prefix non-ICAO addresses with "~", making them 7 chars.

    A VARCHAR(6) column rejected these, and because observations go in as one
    multi-row INSERT the bad row discarded the whole cycle — collection sat at
    zero rows over busy airspace while looking healthy.
    """
    from app.models.skywatch import AircraftTrack
    assert AircraftTrack.__table__.c.hex.type.length >= 7


def test_alert_hex_fits_the_same_identifiers():
    from app.models.skywatch import AircraftAlert
    assert AircraftAlert.__table__.c.hex.type.length >= 7


@pytest.mark.asyncio
@pytest.mark.integration
async def test_tisb_contact_is_recorded(db_session, clean_tracks):
    from app.services.skywatch.tracks import record_observations
    from app.models.skywatch import AircraftTrack

    seen = datetime(2026, 9, 21, 12, 0, tzinfo=timezone.utc)
    written = await record_observations(
        db_session, [Aircraft(hex="~tst050", lat=38.9, lon=-77.0)], seen
    )
    await db_session.commit()
    assert written == 1


@pytest.mark.asyncio
@pytest.mark.integration
async def test_one_overlong_identifier_does_not_discard_the_batch(db_session, clean_tracks):
    """The failure mode migration 015 fixed: lose one row, not the cycle."""
    from app.services.skywatch.tracks import record_observations

    seen = datetime(2026, 9, 21, 12, 1, tzinfo=timezone.utc)
    written = await record_observations(
        db_session,
        [
            Aircraft(hex="tst060", lat=38.9, lon=-77.0),
            Aircraft(hex="x" * 40, lat=38.9, lon=-77.0),
            Aircraft(hex="tst061", lat=38.8, lon=-77.1),
        ],
        seen,
    )
    await db_session.commit()
    assert written == 2

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, time, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.skywatch import (
    AircraftAlert,
    Device,
    MilCallsignPrefix,
    NotableType,
    SkywatchPreference,
)
from app.services.adsb import AdsbServiceError, DataSourceResolver
from app.services.llm import LocalLLMError, is_enabled
from app.services.skywatch.apns import ApnsClient
from app.services.skywatch.copy import alert_copy
from app.services.skywatch.rules import Match, evaluate_aircraft

logger = logging.getLogger(__name__)

# Be gentle with airplanes.live's ~1 req/s rate limit.
INTER_DEVICE_DELAY_SECONDS = 1.0
MAX_DEVICES_PER_CYCLE = 50


def _is_quiet_hours(quiet_hours: dict[str, Any], now: datetime | None = None) -> bool:
    """Return True if `now` falls within the configured quiet window.

    `quiet_hours` is expected to look like `{"start": "HH:MM", "end": "HH:MM",
    "timezone": "IANA/Name"}`. Missing or malformed config is treated as "no
    quiet hours" (never suppress). Supports overnight windows (start > end).
    """
    if not quiet_hours:
        return False

    start_str = quiet_hours.get("start")
    end_str = quiet_hours.get("end")
    if not start_str or not end_str:
        return False

    tz_name = quiet_hours.get("timezone", "UTC")
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = timezone.utc

    try:
        start = time.fromisoformat(start_str)
        end = time.fromisoformat(end_str)
    except ValueError:
        logger.warning("Malformed quiet_hours config, ignoring: %s", quiet_hours)
        return False

    now = (now or datetime.now(timezone.utc)).astimezone(tz)
    current = now.time()

    if start <= end:
        return start <= current < end
    # Overnight window, e.g. 22:00 -> 06:00
    return current >= start or current < end


async def _recent_alert_hexes(
    session: AsyncSession, user_id: str, cooldown_minutes: int, candidate_hexes: set[str]
) -> set[str]:
    if not candidate_hexes:
        return set()
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=cooldown_minutes)
    result = await session.execute(
        select(AircraftAlert.hex).where(
            AircraftAlert.user_id == user_id,
            AircraftAlert.hex.in_(candidate_hexes),
            AircraftAlert.sent_at >= cutoff,
        )
    )
    return {row[0] for row in result.all()}


def _template_alert_copy(aircraft, match: Match) -> tuple[str, str]:
    trigger_titles = {
        "notable_type": "Rare aircraft overhead",
        "military": "Military aircraft overhead",
        "emergency": "Emergency squawk overhead",
        "watchlist": "Watchlist aircraft overhead",
    }
    return trigger_titles.get(match.trigger, "Aircraft overhead"), match.message


async def _build_payload(aircraft, match: Match) -> dict[str, Any]:
    title, body = _template_alert_copy(aircraft, match)

    if is_enabled():
        try:
            llm_copy = await alert_copy(aircraft, match)
        except LocalLLMError:
            llm_copy = None
        except Exception:
            logger.exception("alert_copy raised unexpectedly, using template")
            llm_copy = None
        if llm_copy is not None:
            title, body = llm_copy

    return {
        "aps": {
            "alert": {
                "title": title,
                "body": body,
            },
            "sound": "default",
        },
        "hex": aircraft.hex,
        "trigger": match.trigger,
    }


async def _process_device(
    session: AsyncSession,
    device: Device,
    preference: SkywatchPreference,
    notable_types: dict[str, NotableType],
    mil_prefixes: dict[str, MilCallsignPrefix],
    resolver: DataSourceResolver,
    apns: ApnsClient,
) -> None:
    if _is_quiet_hours(preference.quiet_hours):
        logger.debug("Skipping device %s — quiet hours", device.id)
        return

    lat = float(device.last_lat)
    lon = float(device.last_lng)
    radius_km = float(preference.radius_km)

    try:
        aircraft_list = await resolver.get_aircraft(lat, lon, radius_km)
    except AdsbServiceError as exc:
        logger.warning("ADS-B lookup failed for device %s: %s", device.id, exc)
        return

    # Pre-evaluate matches per aircraft, then batch the cooldown check.
    fired: list[tuple[Any, Match]] = []
    for aircraft in aircraft_list:
        matches = evaluate_aircraft(aircraft, lat, lon, preference, notable_types, mil_prefixes)
        for match in matches:
            fired.append((aircraft, match))

    if not fired:
        return

    candidate_hexes = {aircraft.hex for aircraft, _ in fired}
    on_cooldown = await _recent_alert_hexes(
        session, device.user_id, preference.cooldown_minutes, candidate_hexes
    )

    for aircraft, match in fired:
        if aircraft.hex in on_cooldown:
            continue

        alert = AircraftAlert(
            user_id=device.user_id,
            hex=aircraft.hex,
            callsign=aircraft.flight,
            type=aircraft.type,
            registration=aircraft.registration,
            trigger=match.trigger,
            score=match.score,
            message=match.message,
            lat=aircraft.lat,
            lng=aircraft.lon,
            alt_baro=aircraft.alt_baro,
            distance_km=aircraft.distance_km,
        )
        session.add(alert)
        await session.flush()

        if device.apns_token:
            payload = await _build_payload(aircraft, match)
            try:
                await apns.send(device.apns_token, payload)
            except Exception as exc:
                logger.warning("APNs send failed for device %s: %s", device.id, exc)

        # Prevent duplicate alerts for the same hex within this cycle.
        on_cooldown.add(aircraft.hex)


async def run_watch_cycle(
    session: AsyncSession,
    resolver: DataSourceResolver | None = None,
    apns: ApnsClient | None = None,
) -> None:
    """Run one Skywatch polling cycle for all eligible devices.

    Loads devices with `push_enabled`, a fresh `last_seen` location, and an
    owning user whose `SkywatchPreference` has at least one trigger enabled.
    Errors for an individual device are caught and logged so they don't abort
    the cycle.
    """
    resolver = resolver or DataSourceResolver()
    apns = apns or ApnsClient()

    notable_result = await session.execute(select(NotableType))
    notable_types = {nt.type_code.upper(): nt for nt in notable_result.scalars().all()}

    mil_result = await session.execute(select(MilCallsignPrefix))
    mil_prefixes = {mp.prefix.upper(): mp for mp in mil_result.scalars().all()}

    freshness_cutoff = datetime.now(timezone.utc) - timedelta(
        minutes=settings.skywatch_location_freshness_minutes
    )

    result = await session.execute(
        select(Device, SkywatchPreference)
        .join(SkywatchPreference, SkywatchPreference.user_id == Device.user_id)
        .where(
            Device.push_enabled.is_(True),
            Device.last_lat.is_not(None),
            Device.last_lng.is_not(None),
            Device.last_seen.is_not(None),
            Device.last_seen >= freshness_cutoff,
            (
                SkywatchPreference.notable_types_enabled.is_(True)
                | SkywatchPreference.military_enabled.is_(True)
                | SkywatchPreference.emergency_enabled.is_(True)
                | SkywatchPreference.watchlist_enabled.is_(True)
            ),
        )
        .limit(MAX_DEVICES_PER_CYCLE)
    )
    rows = result.all()

    for index, (device, preference) in enumerate(rows):
        try:
            await _process_device(session, device, preference, notable_types, mil_prefixes, resolver, apns)
        except Exception:
            logger.exception("Skywatch watch cycle failed for device %s", device.id)

        if index < len(rows) - 1:
            await asyncio.sleep(INTER_DEVICE_DELAY_SECONDS)

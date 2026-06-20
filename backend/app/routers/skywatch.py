import asyncio
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.skywatch import (
    AircraftAlert,
    Device,
    MilCallsignPrefix,
    NotableType,
    SkywatchPreference,
)
from app.schemas.skywatch import (
    AircraftAlertRead,
    AircraftMatch,
    DeviceCreate,
    DeviceRead,
    LocationUpdate,
    OverheadAircraft,
    OverheadResponse,
    PreferencesFromText,
    SkywatchPreferenceRead,
    SkywatchPreferenceUpdate,
)
from app.services.adsb import AdsbServiceError, DataSourceResolver
from app.services.aircraft_photos import get_photo_by_hex
from app.services.aircraft_db import get_aircraft_info
from app.services.flightroute import get_route, validate_route
from app.services.search import search_aircraft
from app.services.llm import LocalLLMError
from app.services.skywatch.airlines import resolve_airline
from app.services.skywatch.nl_prefs import compile_preferences
from app.services.skywatch.rules import evaluate_aircraft

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/skywatch", tags=["skywatch"])


async def _get_or_create_preference(db: AsyncSession, user_id: str) -> SkywatchPreference:
    result = await db.execute(
        select(SkywatchPreference).where(SkywatchPreference.user_id == user_id)
    )
    pref = result.scalar_one_or_none()
    if pref is None:
        pref = SkywatchPreference(user_id=user_id)
        db.add(pref)
        await db.flush()
        await db.refresh(pref)
    return pref


@router.post("/devices", response_model=DeviceRead, status_code=201)
async def register_device(
    body: DeviceCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Device:
    device = Device(user_id=user_id, **body.model_dump())
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


@router.post("/location", response_model=DeviceRead)
async def update_location(
    body: LocationUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Device:
    from datetime import datetime, timezone

    device: Device | None = None
    if body.device_id is not None:
        result = await db.execute(
            select(Device).where(Device.id == body.device_id, Device.user_id == user_id)
        )
        device = result.scalar_one_or_none()
        if device is None:
            raise HTTPException(status_code=404, detail="Device not found")
    else:
        result = await db.execute(
            select(Device).where(Device.user_id == user_id).order_by(Device.created_at.desc())
        )
        device = result.scalars().first()
        if device is None:
            raise HTTPException(
                status_code=404,
                detail="No registered device — register a device before updating location",
            )

    device.last_lat = body.lat
    device.last_lng = body.lng
    device.last_seen = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(device)
    return device


@router.get("/overhead", response_model=OverheadResponse)
async def get_overhead(
    user_id: CurrentUser,
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    radius: float | None = Query(None, gt=0, le=463, description="Radius in km (max 463 ≈ 250nm)"),
    db: AsyncSession = Depends(get_db),
) -> OverheadResponse:
    preference = await _get_or_create_preference(db, user_id)
    radius_km = radius if radius is not None else float(preference.radius_km)

    notable_result = await db.execute(select(NotableType))
    notable_types = {nt.type_code.upper(): nt for nt in notable_result.scalars().all()}

    mil_result = await db.execute(select(MilCallsignPrefix))
    mil_prefixes = {mp.prefix.upper(): mp for mp in mil_result.scalars().all()}

    resolver = DataSourceResolver()
    try:
        aircraft = await resolver.get_aircraft(lat, lon, radius_km)
    except AdsbServiceError as exc:
        raise HTTPException(status_code=502, detail=f"ADS-B service unavailable: {exc}") from exc

    items: list[OverheadAircraft] = []
    for ac in aircraft:
        matches = evaluate_aircraft(ac, lat, lon, preference, notable_types, mil_prefixes)
        items.append(
            OverheadAircraft(
                hex=ac.hex,
                flight=ac.flight,
                registration=ac.registration,
                type=ac.type,
                airline=resolve_airline(ac.flight),
                lat=ac.lat,
                lon=ac.lon,
                alt_baro=ac.alt_baro,
                ground_speed=ac.ground_speed,
                track=ac.track,
                squawk=ac.squawk,
                is_military=ac.is_military,
                distance_km=ac.distance_km,
                matches=[AircraftMatch(trigger=m.trigger, score=m.score, message=m.message) for m in matches],
            )
        )

    # Enrich the closest ~15 aircraft with route + photo data concurrently.
    # Failures in enrichment must not break the response — use return_exceptions.
    enrich_targets = sorted(items, key=lambda a: a.distance_km or float("inf"))[:15]

    async def _enrich(item: OverheadAircraft) -> None:
        route_task = get_route(item.flight) if item.flight else asyncio.sleep(0, result=None)
        photo_task = get_photo_by_hex(item.hex)
        results = await asyncio.gather(route_task, photo_task, return_exceptions=True)
        route = results[0] if not isinstance(results[0], Exception) else None
        route = validate_route(route, item.lat, item.lon, item.track)
        photo = results[1] if not isinstance(results[1], Exception) else None
        if route:
            item.origin_iata = route.origin_iata
            item.origin_name = route.origin_name
            item.dest_iata = route.dest_iata
            item.dest_name = route.dest_name
        if photo:
            item.photo_url = photo.photo_url
            item.photo_link = photo.link
            item.photo_credit = photo.photographer

    await asyncio.gather(*[_enrich(item) for item in enrich_targets], return_exceptions=True)

    source = "local+network" if resolver.has_local_source else "network"
    return OverheadResponse(aircraft=items, source=source)


@router.get("/search", response_model=OverheadResponse)
async def search(
    user_id: CurrentUser,
    q: str = Query(..., min_length=1, max_length=12, description="flight/callsign/reg/hex/type/squawk"),
) -> OverheadResponse:
    matches = await search_aircraft(q)
    items: list[OverheadAircraft] = [
        OverheadAircraft(
            hex=ac.hex,
            flight=ac.flight,
            registration=ac.registration,
            type=ac.type,
            airline=resolve_airline(ac.flight),
            lat=ac.lat,
            lon=ac.lon,
            alt_baro=ac.alt_baro,
            ground_speed=ac.ground_speed,
            track=ac.track,
            squawk=ac.squawk,
            is_military=ac.is_military,
            distance_km=ac.distance_km,
            matches=[],
        )
        for ac in matches
    ]

    async def _enrich(item: OverheadAircraft) -> None:
        route_task = get_route(item.flight) if item.flight else asyncio.sleep(0, result=None)
        results = await asyncio.gather(route_task, get_photo_by_hex(item.hex), return_exceptions=True)
        route = results[0] if not isinstance(results[0], Exception) else None
        route = validate_route(route, item.lat, item.lon, item.track)
        photo = results[1] if not isinstance(results[1], Exception) else None
        if route:
            item.origin_iata, item.origin_name = route.origin_iata, route.origin_name
            item.dest_iata, item.dest_name = route.dest_iata, route.dest_name
        if photo:
            item.photo_url, item.photo_link, item.photo_credit = photo.photo_url, photo.link, photo.photographer

    await asyncio.gather(*[_enrich(it) for it in items[:10]], return_exceptions=True)
    return OverheadResponse(aircraft=items, source="search")


@router.get("/aircraft/{hex}", response_model=OverheadAircraft)
async def get_aircraft_detail(
    hex: str,
    user_id: CurrentUser,  # noqa: F841 — auth required
    lat: float = Query(0.0, ge=-90.0, le=90.0),
    lon: float = Query(0.0, ge=-180.0, le=180.0),
) -> OverheadAircraft:
    """Return enriched detail for a single aircraft: route, photo, and trail."""
    import math

    _AIRPLANES_LIVE = "https://api.airplanes.live/v2/hex"
    _TIMEOUT = 6.0

    ac_data: dict = {}
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(f"{_AIRPLANES_LIVE}/{hex}")
            if resp.status_code == 200:
                ac_list = resp.json().get("ac") or []
                if ac_list:
                    ac_data = ac_list[0]
    except Exception as exc:
        logger.debug("airplanes.live detail fetch failed for %s: %s", hex, exc)

    flight = (ac_data.get("flight") or "").strip() or None
    registration = ac_data.get("r") or ac_data.get("reg") or None
    ac_type = ac_data.get("t") or ac_data.get("type") or None
    ac_lat = ac_data.get("lat")
    ac_lon = ac_data.get("lon")
    alt_baro = ac_data.get("alt_baro")
    ground_speed = ac_data.get("gs")
    track = ac_data.get("track")
    squawk = ac_data.get("squawk")

    # Distance from the supplied observer coords
    dist_km: float | None = None
    if ac_lat is not None and ac_lon is not None and lat != 0.0:
        R = 6371.0
        dlat = math.radians(ac_lat - lat)
        dlon = math.radians(ac_lon - lon)
        a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat)) * math.cos(math.radians(ac_lat)) * math.sin(dlon / 2) ** 2
        dist_km = round(R * 2 * math.asin(math.sqrt(a)), 2)

    # Trail from ac_data if present
    raw_trail = ac_data.get("trace") or []
    trail: list[list[float]] = []
    if isinstance(raw_trail, list):
        for pt in raw_trail:
            if isinstance(pt, (list, tuple)) and len(pt) >= 2:
                try:
                    trail.append([float(pt[0]), float(pt[1])])
                except (TypeError, ValueError):
                    pass

    item = OverheadAircraft(
        hex=hex,
        flight=flight,
        registration=registration,
        type=ac_type,
        airline=resolve_airline(flight),
        lat=ac_lat,
        lon=ac_lon,
        alt_baro=int(alt_baro) if alt_baro is not None else None,
        ground_speed=float(ground_speed) if ground_speed is not None else None,
        track=float(track) if track is not None else None,
        squawk=squawk,
        distance_km=dist_km,
        trail=trail,
    )

    # Enrich with route + photo + airframe database
    route, photo, info = await asyncio.gather(
        get_route(flight) if flight else asyncio.sleep(0, result=None),
        get_photo_by_hex(hex),
        get_aircraft_info(registration),
        return_exceptions=True,
    )
    route = validate_route(
        route if not isinstance(route, Exception) else None, ac_lat, ac_lon, item.track
    )
    if route:
        item.origin_iata = route.origin_iata
        item.origin_name = route.origin_name
        item.dest_iata = route.dest_iata
        item.dest_name = route.dest_name
    if photo and not isinstance(photo, Exception):
        item.photo_url = photo.photo_url
        item.photo_link = photo.link
        item.photo_credit = photo.photographer
    if info and not isinstance(info, Exception):
        item.manufacturer = info.manufacturer
        item.aircraft_type_long = info.type_long
        item.owner = info.owner
        item.owner_country = info.owner_country

    return item


@router.get("/preferences", response_model=SkywatchPreferenceRead)
async def get_preferences(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> SkywatchPreference:
    return await _get_or_create_preference(db, user_id)


@router.put("/preferences", response_model=SkywatchPreferenceRead)
async def update_preferences(
    body: SkywatchPreferenceUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> SkywatchPreference:
    preference = await _get_or_create_preference(db, user_id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(preference, k, v)
    await db.flush()
    await db.refresh(preference)
    return preference


@router.post("/preferences/from-text", response_model=SkywatchPreferenceRead)
async def update_preferences_from_text(
    body: PreferencesFromText,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> SkywatchPreference:
    preference = await _get_or_create_preference(db, user_id)

    try:
        updates = await compile_preferences(body.text, preference)
    except LocalLLMError as exc:
        raise HTTPException(status_code=503, detail=f"Local LLM unavailable: {exc}") from exc

    for k, v in updates.items():
        setattr(preference, k, v)
    preference.nl_prompt = body.text

    await db.flush()
    await db.refresh(preference)
    return preference


@router.get("/alerts", response_model=list[AircraftAlertRead])
async def list_alerts(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
) -> list[AircraftAlert]:
    result = await db.execute(
        select(AircraftAlert)
        .where(AircraftAlert.user_id == user_id)
        .order_by(AircraftAlert.sent_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())

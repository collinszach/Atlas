import logging

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
    SkywatchPreferenceRead,
    SkywatchPreferenceUpdate,
)
from app.services.adsb import AdsbServiceError, DataSourceResolver
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

    source = "local+network" if resolver.has_local_source else "network"
    return OverheadResponse(aircraft=items, source=source)


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

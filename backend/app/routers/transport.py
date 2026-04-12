import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.transport import TransportLeg
from app.models.trip import Trip
from app.schemas.transport import TransportCreate, TransportRead, TransportUpdate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["transport"])


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/transport", response_model=list[TransportRead])
async def list_transport(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[TransportRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(TransportLeg)
        .where(TransportLeg.trip_id == trip_id, TransportLeg.user_id == user_id)
        .order_by(TransportLeg.departure_at.nullslast())
    )
    legs = result.scalars().all()
    return [TransportRead.from_orm_with_geo(leg) for leg in legs]


@router.post("/trips/{trip_id}/transport", response_model=TransportRead, status_code=201)
async def add_transport(
    trip_id: uuid.UUID,
    body: TransportCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransportRead:
    await _get_trip_or_404(trip_id, user_id, db)

    origin_geo = None
    dest_geo = None
    if body.origin_lat is not None:
        origin_geo = from_shape(Point(body.origin_lng, body.origin_lat), srid=4326)
    if body.dest_lat is not None:
        dest_geo = from_shape(Point(body.dest_lng, body.dest_lat), srid=4326)

    leg = TransportLeg(
        trip_id=trip_id,
        user_id=user_id,
        type=body.type,
        flight_number=body.flight_number,
        airline=body.airline,
        origin_iata=body.origin_iata,
        dest_iata=body.dest_iata,
        origin_city=body.origin_city,
        dest_city=body.dest_city,
        departure_at=body.departure_at,
        arrival_at=body.arrival_at,
        duration_min=body.duration_min,
        distance_km=body.distance_km,
        seat_class=body.seat_class,
        booking_ref=body.booking_ref,
        cost=body.cost,
        currency=body.currency,
        notes=body.notes,
        origin_geo=origin_geo,
        dest_geo=dest_geo,
    )
    db.add(leg)
    await db.flush()
    await db.refresh(leg)
    return TransportRead.from_orm_with_geo(leg)


@router.put("/transport/{leg_id}", response_model=TransportRead)
async def update_transport(
    leg_id: uuid.UUID,
    body: TransportUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransportRead:
    result = await db.execute(
        select(TransportLeg).where(TransportLeg.id == leg_id, TransportLeg.user_id == user_id)
    )
    leg = result.scalar_one_or_none()
    if leg is None:
        raise HTTPException(status_code=404, detail="Transport leg not found")

    update_data = body.model_dump(exclude_none=True)
    origin_lat = update_data.pop("origin_lat", None)
    origin_lng = update_data.pop("origin_lng", None)
    dest_lat = update_data.pop("dest_lat", None)
    dest_lng = update_data.pop("dest_lng", None)

    if origin_lat is not None and origin_lng is not None:
        leg.origin_geo = from_shape(Point(origin_lng, origin_lat), srid=4326)
    if dest_lat is not None and dest_lng is not None:
        leg.dest_geo = from_shape(Point(dest_lng, dest_lat), srid=4326)

    for k, v in update_data.items():
        setattr(leg, k, v)

    await db.flush()
    await db.refresh(leg)
    return TransportRead.from_orm_with_geo(leg)


@router.delete("/transport/{leg_id}", status_code=204)
async def delete_transport(
    leg_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(TransportLeg).where(TransportLeg.id == leg_id, TransportLeg.user_id == user_id)
    )
    leg = result.scalar_one_or_none()
    if leg is None:
        raise HTTPException(status_code=404, detail="Transport leg not found")
    await db.delete(leg)
    await db.flush()

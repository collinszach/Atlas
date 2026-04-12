import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.accommodation import Accommodation
from app.models.trip import Trip
from app.schemas.accommodation import AccommodationCreate, AccommodationRead, AccommodationUpdate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["accommodations"])


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/accommodations", response_model=list[AccommodationRead])
async def list_accommodations(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[AccommodationRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(Accommodation)
        .where(Accommodation.trip_id == trip_id, Accommodation.user_id == user_id)
        .order_by(Accommodation.check_in.nullslast())
    )
    accs = result.scalars().all()
    return [AccommodationRead.from_orm_with_geo(a) for a in accs]


@router.post("/trips/{trip_id}/accommodations", response_model=AccommodationRead, status_code=201)
async def add_accommodation(
    trip_id: uuid.UUID,
    body: AccommodationCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AccommodationRead:
    await _get_trip_or_404(trip_id, user_id, db)

    location = None
    if body.latitude is not None and body.longitude is not None:
        location = from_shape(Point(body.longitude, body.latitude), srid=4326)

    acc = Accommodation(
        trip_id=trip_id,
        user_id=user_id,
        destination_id=body.destination_id,
        name=body.name,
        type=body.type,
        address=body.address,
        location=location,
        check_in=body.check_in,
        check_out=body.check_out,
        confirmation=body.confirmation,
        cost_per_night=body.cost_per_night,
        currency=body.currency,
        rating=body.rating,
        notes=body.notes,
    )
    db.add(acc)
    await db.flush()
    await db.refresh(acc)
    return AccommodationRead.from_orm_with_geo(acc)


@router.put("/accommodations/{acc_id}", response_model=AccommodationRead)
async def update_accommodation(
    acc_id: uuid.UUID,
    body: AccommodationUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AccommodationRead:
    result = await db.execute(
        select(Accommodation).where(Accommodation.id == acc_id, Accommodation.user_id == user_id)
    )
    acc = result.scalar_one_or_none()
    if acc is None:
        raise HTTPException(status_code=404, detail="Accommodation not found")

    update_data = body.model_dump(exclude_none=True)
    lat = update_data.pop("latitude", None)
    lng = update_data.pop("longitude", None)
    if lat is not None and lng is not None:
        acc.location = from_shape(Point(lng, lat), srid=4326)

    for k, v in update_data.items():
        setattr(acc, k, v)

    await db.flush()
    await db.refresh(acc)
    return AccommodationRead.from_orm_with_geo(acc)


@router.delete("/accommodations/{acc_id}", status_code=204)
async def delete_accommodation(
    acc_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(Accommodation).where(Accommodation.id == acc_id, Accommodation.user_id == user_id)
    )
    acc = result.scalar_one_or_none()
    if acc is None:
        raise HTTPException(status_code=404, detail="Accommodation not found")
    await db.delete(acc)
    await db.flush()

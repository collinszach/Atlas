import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.trip import Trip
from app.schemas.trip import TripCreate, TripRead, TripUpdate, TripListResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/trips", tags=["trips"])


@router.get("", response_model=TripListResponse)
async def list_trips(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status: str | None = None,
) -> TripListResponse:
    q = select(Trip).where(Trip.user_id == user_id)
    if status:
        q = q.where(Trip.status == status)

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()

    q = q.order_by(Trip.updated_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(q)
    trips = result.scalars().all()

    return TripListResponse(items=list(trips), total=total, page=page, limit=limit)


@router.post("", response_model=TripRead, status_code=201)
async def create_trip(
    body: TripCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Trip:
    trip = Trip(user_id=user_id, **body.model_dump())
    db.add(trip)
    await db.flush()
    await db.refresh(trip)
    return trip


@router.get("/{trip_id}", response_model=TripRead)
async def get_trip(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.put("/{trip_id}", response_model=TripRead)
async def update_trip(
    trip_id: uuid.UUID,
    body: TripUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(trip, k, v)
    await db.flush()
    await db.refresh(trip)
    return trip


@router.delete("/{trip_id}", status_code=204)
async def delete_trip(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    await db.delete(trip)
    await db.flush()

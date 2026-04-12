import logging
import uuid
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.shape import from_shape
from shapely.geometry import Point

from app.auth import CurrentUser
from app.database import get_db
from app.models.destination import Destination
from app.models.trip import Trip
from app.schemas.destination import DestinationCreate, DestinationRead, DestinationUpdate, DestinationReorderItem

logger = logging.getLogger(__name__)
router = APIRouter(tags=["destinations"])


async def _refresh_country_visits(user_id: str) -> None:
    """Refresh country_visits materialized view. Called as a FastAPI background task.

    Note: REFRESH MATERIALIZED VIEW is a global operation — it refreshes all rows,
    not just those for `user_id`. The user_id parameter is used for logging only.

    REFRESH MATERIALIZED VIEW CONCURRENTLY cannot run inside a transaction block.
    We use AUTOCOMMIT isolation to execute it outside of any transaction.
    """
    from app.database import engine
    try:
        # REFRESH MATERIALIZED VIEW CONCURRENTLY cannot run inside a transaction.
        # Use AUTOCOMMIT isolation to bypass SQLAlchemy's implicit BEGIN.
        async with engine.execution_options(isolation_level="AUTOCOMMIT").connect() as conn:
            await conn.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY country_visits"))
        logger.info("Refreshed country_visits for user %s", user_id)
    except Exception as exc:
        logger.warning("Failed to refresh country_visits: %s", exc)


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/destinations", response_model=list[DestinationRead])
async def list_destinations(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[DestinationRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(Destination)
        .where(Destination.trip_id == trip_id, Destination.user_id == user_id)
        .order_by(Destination.order_index, Destination.arrival_date)
    )
    dests = result.scalars().all()
    return [DestinationRead.from_orm_with_geo(d) for d in dests]


@router.post("/trips/{trip_id}/destinations", response_model=DestinationRead, status_code=201)
async def add_destination(
    trip_id: uuid.UUID,
    body: DestinationCreate,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> DestinationRead:
    await _get_trip_or_404(trip_id, user_id, db)

    location = None
    if body.latitude is not None and body.longitude is not None:
        location = from_shape(Point(body.longitude, body.latitude), srid=4326)

    dest = Destination(
        trip_id=trip_id,
        user_id=user_id,
        city=body.city,
        country_code=body.country_code,
        country_name=body.country_name,
        region=body.region,
        location=location,
        arrival_date=body.arrival_date,
        departure_date=body.departure_date,
        notes=body.notes,
        rating=body.rating,
        order_index=body.order_index,
    )
    db.add(dest)
    await db.flush()
    await db.refresh(dest)
    background_tasks.add_task(_refresh_country_visits, user_id)
    return DestinationRead.from_orm_with_geo(dest)


@router.put("/destinations/{dest_id}", response_model=DestinationRead)
async def update_destination(
    dest_id: uuid.UUID,
    body: DestinationUpdate,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> DestinationRead:
    result = await db.execute(
        select(Destination).where(Destination.id == dest_id, Destination.user_id == user_id)
    )
    dest = result.scalar_one_or_none()
    if dest is None:
        raise HTTPException(status_code=404, detail="Destination not found")

    update_data = body.model_dump(exclude_none=True)
    lat = update_data.pop("latitude", None)
    lng = update_data.pop("longitude", None)
    if lat is not None and lng is not None:
        dest.location = from_shape(Point(lng, lat), srid=4326)

    for k, v in update_data.items():
        setattr(dest, k, v)

    await db.flush()
    await db.refresh(dest)
    background_tasks.add_task(_refresh_country_visits, user_id)
    return DestinationRead.from_orm_with_geo(dest)


@router.delete("/destinations/{dest_id}", status_code=204)
async def delete_destination(
    dest_id: uuid.UUID,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(Destination).where(Destination.id == dest_id, Destination.user_id == user_id)
    )
    dest = result.scalar_one_or_none()
    if dest is None:
        raise HTTPException(status_code=404, detail="Destination not found")
    await db.delete(dest)
    await db.flush()
    background_tasks.add_task(_refresh_country_visits, user_id)


@router.patch("/trips/{trip_id}/destinations/reorder", response_model=list[DestinationRead])
async def reorder_destinations(
    trip_id: uuid.UUID,
    body: list[DestinationReorderItem],
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[DestinationRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    for item in body:
        await db.execute(
            update(Destination)
            .where(
                Destination.id == item.id,
                Destination.trip_id == trip_id,
                Destination.user_id == user_id,
            )
            .values(order_index=item.order_index)
        )
    await db.flush()
    result = await db.execute(
        select(Destination)
        .where(Destination.trip_id == trip_id, Destination.user_id == user_id)
        .order_by(Destination.order_index, Destination.arrival_date)
    )
    dests = result.scalars().all()
    return [DestinationRead.from_orm_with_geo(d) for d in dests]

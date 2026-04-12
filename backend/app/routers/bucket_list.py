import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.bucket_list import BucketList
from app.schemas.bucket_list import BucketListCreate, BucketListRead, BucketListUpdate

router = APIRouter(prefix="/bucket-list", tags=["bucket-list"])


@router.get("", response_model=list[BucketListRead])
async def list_bucket_list(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[BucketList]:
    result = await db.execute(
        select(BucketList)
        .where(BucketList.user_id == user_id)
        .order_by(BucketList.priority.desc(), BucketList.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("", response_model=BucketListRead, status_code=201)
async def create_bucket_list_item(
    body: BucketListCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> BucketList:
    item = BucketList(user_id=user_id, **body.model_dump())
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return item


@router.put("/{item_id}", response_model=BucketListRead)
async def update_bucket_list_item(
    item_id: uuid.UUID,
    body: BucketListUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> BucketList:
    result = await db.execute(
        select(BucketList).where(BucketList.id == item_id, BucketList.user_id == user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Bucket list item not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    await db.flush()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_bucket_list_item(
    item_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(BucketList).where(BucketList.id == item_id, BucketList.user_id == user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Bucket list item not found")
    await db.delete(item)
    await db.flush()

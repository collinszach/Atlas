import logging
from fastapi import APIRouter, Request, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import verify_webhook_signature, CurrentUser
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserRead

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["users"])


@router.post("/sync", status_code=204)
async def sync_user(request: Request, db: AsyncSession = Depends(get_db)):
    """Clerk webhook — upsert user on create/update events."""
    raw_body = await request.body()
    verify_webhook_signature(request, raw_body)

    event = await request.json()
    event_type = event.get("type")
    if event_type not in ("user.created", "user.updated"):
        return

    data = event.get("data", {})
    user_id = data.get("id")
    emails = data.get("email_addresses", [])
    primary_email = next(
        (e["email_address"] for e in emails if e.get("id") == data.get("primary_email_address_id")),
        emails[0]["email_address"] if emails else None,
    )
    if not user_id or not primary_email:
        logger.warning("Webhook missing user_id or email: %s", data)
        raise HTTPException(status_code=400, detail="Malformed webhook payload — missing user_id or email")

    display_name = " ".join(filter(None, [data.get("first_name"), data.get("last_name")])) or None

    stmt = (
        insert(User)
        .values(id=user_id, email=primary_email, display_name=display_name, avatar_url=data.get("image_url"))
        .on_conflict_do_update(
            index_elements=["id"],
            set_={"email": primary_email, "display_name": display_name, "avatar_url": data.get("image_url")},
        )
    )
    await db.execute(stmt)
    await db.commit()
    logger.info("Upserted user %s", user_id)


@router.get("/me", response_model=UserRead)
async def get_me(user_id: CurrentUser, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found — complete sign-up first")
    return user

import uuid
from datetime import datetime, date
from pydantic import BaseModel


class TripCreate(BaseModel):
    title: str
    description: str | None = None
    status: str = "past"
    start_date: date | None = None
    end_date: date | None = None
    tags: list[str] = []
    visibility: str = "private"


class TripUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    tags: list[str] | None = None
    visibility: str | None = None


class TripRead(BaseModel):
    id: uuid.UUID
    user_id: str
    title: str
    description: str | None
    status: str
    start_date: date | None
    end_date: date | None
    tags: list[str]
    visibility: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TripListResponse(BaseModel):
    items: list[TripRead]
    total: int
    page: int
    limit: int

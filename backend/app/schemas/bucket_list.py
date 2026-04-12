from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, model_validator

_VALID_SEASONS = {"spring", "summer", "fall", "winter", "any"}


class BucketListCreate(BaseModel):
    country_code: str | None = None
    country_name: str | None = None
    city: str | None = None
    priority: int = 3
    reason: str | None = None
    ideal_season: str | None = None
    estimated_cost: Decimal | None = None
    trip_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def validate_fields(self) -> "BucketListCreate":
        if not (1 <= self.priority <= 5):
            raise ValueError("priority must be between 1 and 5")
        if self.ideal_season is not None and self.ideal_season not in _VALID_SEASONS:
            raise ValueError(f"ideal_season must be one of {sorted(_VALID_SEASONS)}")
        return self


class BucketListUpdate(BaseModel):
    country_code: str | None = None
    country_name: str | None = None
    city: str | None = None
    priority: int | None = None
    reason: str | None = None
    ideal_season: str | None = None
    estimated_cost: Decimal | None = None
    trip_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def validate_fields(self) -> "BucketListUpdate":
        if self.priority is not None and not (1 <= self.priority <= 5):
            raise ValueError("priority must be between 1 and 5")
        if self.ideal_season is not None and self.ideal_season not in _VALID_SEASONS:
            raise ValueError(f"ideal_season must be one of {sorted(_VALID_SEASONS)}")
        return self


class BucketListRead(BaseModel):
    id: uuid.UUID
    user_id: str
    country_code: str | None
    country_name: str | None
    city: str | None
    priority: int
    reason: str | None
    ideal_season: str | None
    estimated_cost: Decimal | None
    trip_id: uuid.UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}

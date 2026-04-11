import json
import logging
from typing import Any

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)
MAP_TTL = 300  # 5 minutes

_redis: aioredis.Redis | None = None


def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    return _redis


async def get_cached(key: str) -> Any | None:
    try:
        value = await get_redis().get(key)
        return json.loads(value) if value else None
    except Exception as exc:
        logger.warning("Redis get failed for %s: %s", key, exc)
        return None


async def set_cached(key: str, value: Any, ttl: int = MAP_TTL) -> None:
    try:
        await get_redis().setex(key, ttl, json.dumps(value))
    except Exception as exc:
        logger.warning("Redis set failed for %s: %s", key, exc)

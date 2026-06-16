"""Aircraft photo lookup via planespotters.net (free, no key required).

GET https://api.planespotters.net/pub/photos/hex/{hex}
GET https://api.planespotters.net/pub/photos/reg/{reg}

In-memory cache with ~24h TTL since photos rarely change.
"""
from __future__ import annotations

import logging
import time
from typing import NamedTuple

import httpx

logger = logging.getLogger(__name__)

_BASE = "https://api.planespotters.net/pub/photos"
_TIMEOUT = 5.0
_TTL = 24 * 3600  # 24 hours

# Cache: hex|reg -> (result | None, expiry_ts)
_cache: dict[str, tuple["PhotoInfo | None", float]] = {}


class PhotoInfo(NamedTuple):
    photo_url: str
    link: str
    photographer: str | None


async def get_photo_by_hex(hex_code: str) -> PhotoInfo | None:
    """Fetch aircraft photo by ICAO hex address. Returns None on any error."""
    key = f"hex:{hex_code.lower()}"
    return await _get_cached(key, f"{_BASE}/hex/{hex_code}")


async def get_photo_by_reg(registration: str) -> PhotoInfo | None:
    """Fetch aircraft photo by registration. Returns None on any error."""
    key = f"reg:{registration.upper()}"
    return await _get_cached(key, f"{_BASE}/reg/{registration}")


async def _get_cached(key: str, url: str) -> PhotoInfo | None:
    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None:
        result, expiry = cached
        if now < expiry:
            return result

    result = await _fetch_photo(url)
    _cache[key] = (result, now + _TTL)
    return result


async def _fetch_photo(url: str) -> PhotoInfo | None:
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(url, headers={"User-Agent": "Atlas-FlightApp/1.0"})
            if resp.status_code != 200:
                return None
            data = resp.json()
    except Exception as exc:
        logger.debug("planespotters fetch failed for %s: %s", url, exc)
        return None

    try:
        photos = data.get("photos") or []
        if not photos:
            return None
        p = photos[0]
        thumb = p.get("thumbnail_large") or p.get("thumbnail") or {}
        photo_url = thumb.get("src") or ""
        if not photo_url:
            return None
        return PhotoInfo(
            photo_url=photo_url,
            link=p.get("link") or "",
            photographer=p.get("photographer") or None,
        )
    except Exception as exc:
        logger.debug("planespotters parse error: %s", exc)
        return None

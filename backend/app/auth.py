import asyncio
import logging
import time
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, Request, status
from jose import JWTError, jwt
from standardwebhooks import Webhook, WebhookVerificationError

from app.config import settings

logger = logging.getLogger(__name__)

_jwks_cache: dict | None = None
_jwks_fetched_at: float = 0.0
_JWKS_TTL = 3600.0  # re-fetch after 1 hour
_jwks_lock = asyncio.Lock()


async def _get_jwks(force_refresh: bool = False) -> dict:
    global _jwks_cache, _jwks_fetched_at
    async with _jwks_lock:
        if _jwks_cache is None or force_refresh or (time.monotonic() - _jwks_fetched_at) > _JWKS_TTL:
            async with httpx.AsyncClient() as http_client:
                resp = await http_client.get(
                    "https://api.clerk.com/v1/jwks",
                    headers={"Authorization": f"Bearer {settings.clerk_secret_key}"},
                )
                resp.raise_for_status()
                _jwks_cache = resp.json()
                _jwks_fetched_at = time.monotonic()
    return _jwks_cache


async def get_current_user_id(request: Request) -> str:
    """Extract and verify Clerk JWT. Returns Clerk user_id string."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authorization header")

    token = auth_header.removeprefix("Bearer ").strip()
    try:
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        jwks = await _get_jwks()
        key = next((k for k in jwks.get("keys", []) if k["kid"] == kid), None)
        if key is None:
            # kid not in cache — attempt one refresh in case of key rotation
            jwks = await _get_jwks(force_refresh=True)
            key = next((k for k in jwks.get("keys", []) if k["kid"] == kid), None)
        if key is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown signing key")
        payload = jwt.decode(token, key, algorithms=["RS256"])
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
        return user_id
    except JWTError as exc:
        logger.warning("JWT validation failed: %s", exc)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except httpx.HTTPError as exc:
        logger.error("JWKS fetch failed: %s", exc)
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Auth service unavailable")


CurrentUser = Annotated[str, Depends(get_current_user_id)]


def verify_webhook_signature(request: Request, payload: bytes) -> None:
    """Verify Clerk webhook via Standard Webhooks signature headers (svix-id, svix-timestamp, svix-signature)."""
    wh = Webhook(settings.clerk_webhook_secret)
    try:
        wh.verify(
            payload,
            {
                "svix-id": request.headers.get("svix-id", ""),
                "svix-timestamp": request.headers.get("svix-timestamp", ""),
                "svix-signature": request.headers.get("svix-signature", ""),
            },
        )
    except WebhookVerificationError as exc:
        logger.warning("Webhook verification failed: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid webhook signature")

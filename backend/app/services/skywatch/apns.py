from __future__ import annotations
import logging
import time
from pathlib import Path

import httpx
from jose import jwt

from app.config import settings

logger = logging.getLogger(__name__)

APNS_ALGORITHM = "ES256"
APNS_TOKEN_TTL_SECONDS = 3000  # Apple recommends refreshing before 1 hour
APNS_PRODUCTION_HOST = "https://api.push.apple.com"
APNS_SANDBOX_HOST = "https://api.sandbox.push.apple.com"


class ApnsConfigError(Exception):
    """Raised when APNs credentials are required but not configured."""


class ApnsClient:
    """Token-based (JWT) APNs client.

    If `apns_key_id`, `apns_team_id`, or `apns_auth_key` are unset, `send()`
    logs and no-ops instead of raising — push is optional until P3 provisions
    Apple Developer credentials.
    """

    def __init__(
        self,
        key_id: str | None = None,
        team_id: str | None = None,
        auth_key: str | None = None,
        bundle_id: str | None = None,
        sandbox: bool | None = None,
    ) -> None:
        if sandbox is None:
            sandbox = settings.apns_use_sandbox
        self._key_id = key_id if key_id is not None else settings.apns_key_id
        self._team_id = team_id if team_id is not None else settings.apns_team_id
        raw_auth_key = auth_key if auth_key is not None else settings.apns_auth_key
        self._auth_key = self._resolve_auth_key(raw_auth_key)
        self._bundle_id = bundle_id if bundle_id is not None else settings.apns_bundle_id
        self._host = APNS_SANDBOX_HOST if sandbox else APNS_PRODUCTION_HOST

        self._cached_token: str | None = None
        self._cached_token_issued_at: float = 0.0

    @staticmethod
    def _resolve_auth_key(value: str) -> str:
        """Accept either the .p8 PEM contents or a filesystem path to it.

        A path lets the key live in a gitignored secrets dir instead of inline
        in env. If the value points to a readable file, return its contents;
        otherwise treat the value itself as the PEM.
        """
        if not value:
            return ""
        if "BEGIN PRIVATE KEY" in value:
            return value
        candidate = Path(value)
        if candidate.is_file():
            return candidate.read_text()
        # The path may be recorded relative to the repo root (e.g.
        # "backend/secrets/AuthKey.p8") while the process runs from the backend
        # root (Docker WORKDIR /app, or local pytest). Fall back to the backend
        # package root and its secrets/ dir so it resolves either way.
        backend_root = Path(__file__).resolve().parents[3]
        for alt in (backend_root / value, backend_root / "secrets" / candidate.name):
            if alt.is_file():
                return alt.read_text()
        return value

    @property
    def is_configured(self) -> bool:
        return bool(self._key_id and self._team_id and self._auth_key)

    def _build_provider_token(self) -> str:
        if not self.is_configured:
            raise ApnsConfigError("APNs credentials are not configured")

        now = time.time()
        if self._cached_token and (now - self._cached_token_issued_at) < APNS_TOKEN_TTL_SECONDS:
            return self._cached_token

        token = jwt.encode(
            {"iss": self._team_id, "iat": int(now)},
            self._auth_key,
            algorithm=APNS_ALGORITHM,
            headers={"kid": self._key_id},
        )
        self._cached_token = token
        self._cached_token_issued_at = now
        return token

    async def send(self, device_token: str, payload: dict, priority: int = 10) -> None:
        """Send a push notification via APNs HTTP/2.

        No-ops with a log message if APNs credentials are not configured.
        Raises httpx.HTTPError on a failed request once configured.
        """
        if not self.is_configured:
            logger.info(
                "APNs not configured — skipping push to device %s: %s",
                device_token,
                payload,
            )
            return

        provider_token = self._build_provider_token()
        url = f"{self._host}/3/device/{device_token}"
        headers = {
            "authorization": f"bearer {provider_token}",
            "apns-topic": self._bundle_id,
            "apns-priority": str(priority),
            "apns-push-type": "alert",
        }

        async with httpx.AsyncClient(http2=True, timeout=10.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
            resp.raise_for_status()

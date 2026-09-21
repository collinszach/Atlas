from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # APNs credentials live in the gitignored secrets/apns.env; later files in
    # the tuple win, and real environment variables still override both.
    model_config = SettingsConfigDict(
        env_file=(".env", "secrets/apns.env"), extra="ignore"
    )

    # Database
    database_url: str
    database_url_sync: str

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Clerk
    clerk_secret_key: str = ""
    clerk_webhook_secret: str = ""
    clerk_jwks_url: str = ""  # public well-known JWKS; when set, no secret needed for JWT verify

    # MinIO
    minio_endpoint: str = "atlas-minio:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket_photos: str = "atlas-photos"
    minio_public_url: str = "http://localhost:9000"
    storage_backend: str = "minio"

    # Local LLM (Ollama, per-task — opt-in)
    local_llm_base: str = ""
    local_llm_model: str = "qwen2.5:7b"

    # Skywatch
    airplanes_live_base: str = "https://api.airplanes.live/v2"
    dump1090_url: str = ""
    apns_key_id: str = ""
    apns_team_id: str = ""
    apns_auth_key: str = ""
    apns_bundle_id: str = "com.zacharyjcollins.atlas"  # must match the app's bundle id (APNs topic)
    apns_use_sandbox: bool = True  # dev-signed apps must use the sandbox APNs host
    skywatch_default_radius_km: float = 30.0
    skywatch_poll_seconds: int = 20
    skywatch_location_freshness_minutes: int = 15
    # Observation retention. At a 20s poll with ~30 aircraft in radius this is
    # roughly 130k rows/day per distinct observed area; 30 days keeps enough
    # history for route inference without unbounded growth on the NUC.
    # Collection radius for aircraft_tracks, deliberately independent of the
    # per-user alert radius. That radius is tuned for "how often do I want to be
    # interrupted" and is often small — one user had it at 5km, which recorded
    # only low helicopters. History for route/ETA work needs a wide net, and
    # alerting still filters to the user's own radius afterwards.
    skywatch_track_radius_km: float = 120.0
    skywatch_track_retention_days: int = 30
    skywatch_track_prune_hour: int = 4

    # Flight enrichment (optional)
    aviationstack_api_key: str = ""

    # App
    app_env: str = "development"


settings = Settings()

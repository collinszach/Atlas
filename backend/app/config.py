from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database
    database_url: str
    database_url_sync: str

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Clerk
    clerk_secret_key: str
    clerk_webhook_secret: str

    # MinIO
    minio_endpoint: str = "atlas-minio:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket_photos: str = "atlas-photos"
    minio_public_url: str = "http://localhost:9000"
    storage_backend: str = "minio"

    # AI
    anthropic_api_key: str = ""

    # Flight enrichment (optional)
    aviationstack_api_key: str = ""

    # App
    app_env: str = "development"


settings = Settings()

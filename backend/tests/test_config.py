def test_settings_load():
    from app.config import settings
    assert settings.database_url.startswith("postgresql")
    assert settings.redis_url.startswith("redis://")
    assert settings.clerk_secret_key != ""

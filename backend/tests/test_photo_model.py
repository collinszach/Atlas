import pytest


def test_photo_model_importable():
    from app.models.photo import Photo
    assert Photo.__tablename__ == "photos"


def test_photo_model_fields():
    from app.models.photo import Photo
    cols = {c.name for c in Photo.__table__.columns}
    assert {"id", "user_id", "trip_id", "storage_key", "is_cover", "taken_at"}.issubset(cols)


@pytest.mark.asyncio
async def test_photos_table_exists(db_session):
    from sqlalchemy import text
    result = await db_session.execute(
        text("SELECT 1 FROM information_schema.tables WHERE table_name = 'photos'")
    )
    assert result.scalar_one_or_none() == 1

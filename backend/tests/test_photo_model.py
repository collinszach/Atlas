import pytest


def test_photo_model_importable():
    from app.models.photo import Photo
    assert Photo.__tablename__ == "photos"


def test_photo_model_fields():
    from app.models.photo import Photo
    cols = {c.name for c in Photo.__table__.columns}
    assert {"id", "user_id", "trip_id", "storage_key", "is_cover", "taken_at"}.issubset(cols)

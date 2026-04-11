def test_user_model_has_required_columns():
    from app.models.user import User
    cols = {c.name for c in User.__table__.columns}
    assert {"id", "email", "display_name", "avatar_url", "home_country", "preferences", "created_at"}.issubset(cols)


def test_trip_model_has_required_columns():
    from app.models.trip import Trip
    cols = {c.name for c in Trip.__table__.columns}
    assert {"id", "user_id", "title", "description", "status", "visibility", "tags", "start_date", "end_date", "created_at", "updated_at"}.issubset(cols)


def test_destination_model_has_required_columns():
    from app.models.destination import Destination
    cols = {c.name for c in Destination.__table__.columns}
    assert {"id", "trip_id", "user_id", "city", "country_code", "country_name", "location", "arrival_date", "departure_date", "nights", "notes", "rating", "order_index", "created_at"}.issubset(cols)


def test_destination_nights_computed():
    from datetime import date
    from app.models.destination import Destination
    d = Destination(
        city="Paris",
        country_code="FR",
        country_name="France",
        arrival_date=date(2024, 6, 1),
        departure_date=date(2024, 6, 5),
    )
    assert d.nights == 4


def test_models_init_exports_all():
    from app import models
    assert hasattr(models, "User")
    assert hasattr(models, "Trip")
    assert hasattr(models, "Destination")
    assert hasattr(models, "TransportLeg")
    assert hasattr(models, "Accommodation")

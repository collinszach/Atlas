def test_user_model_has_required_columns():
    from app.models.user import User
    cols = {c.name for c in User.__table__.columns}
    assert {"id", "email", "display_name", "avatar_url", "home_country", "preferences", "created_at"}.issubset(cols)


def test_models_init_exports_all():
    from app import models
    assert hasattr(models, "User")
    assert hasattr(models, "TransportLeg")
    assert hasattr(models, "Photo")

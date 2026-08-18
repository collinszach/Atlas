import pytest


def test_transport_leg_model_importable():
    from app.models.transport import TransportLeg
    assert TransportLeg.__tablename__ == "transport_legs"


def test_transport_leg_model_has_flight_fields():
    from app.models.transport import TransportLeg
    cols = {c.name for c in TransportLeg.__table__.columns}
    assert {
        "id", "user_id",
        "flight_number", "airline", "origin_iata", "dest_iata",
        "origin_city", "dest_city",
        "departure_at", "arrival_at", "duration_min", "distance_km",
        "seat_class", "booking_ref", "cost", "currency", "notes",
        "origin_geo", "dest_geo", "created_at",
    }.issubset(cols)


@pytest.mark.asyncio
async def test_transport_table_has_geo_columns(db_session):
    from sqlalchemy import text
    result = await db_session.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'transport_legs'"
        )
    )
    cols = {r[0] for r in result.fetchall()}
    assert {"flight_number", "origin_geo", "dest_geo", "departure_at"}.issubset(cols)

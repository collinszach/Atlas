"""Expand transport_legs and accommodations with full fields

Revision ID: 005
Revises: 004
Create Date: 2026-04-11
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
import geoalchemy2

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- transport_legs ---
    op.add_column("transport_legs", sa.Column("flight_number", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("airline", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("origin_iata", sa.String(3), nullable=True))
    op.add_column("transport_legs", sa.Column("dest_iata", sa.String(3), nullable=True))
    op.add_column("transport_legs", sa.Column("origin_city", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("dest_city", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("departure_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transport_legs", sa.Column("arrival_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transport_legs", sa.Column("duration_min", sa.Integer, nullable=True))
    op.add_column("transport_legs", sa.Column("distance_km", sa.Numeric(10, 2), nullable=True))
    op.add_column("transport_legs", sa.Column("seat_class", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("booking_ref", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("cost", sa.Numeric(10, 2), nullable=True))
    op.add_column("transport_legs", sa.Column("currency", sa.String(3), nullable=False, server_default="USD"))
    op.add_column("transport_legs", sa.Column("notes", sa.Text, nullable=True))
    op.add_column(
        "transport_legs",
        sa.Column("origin_geo", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.add_column(
        "transport_legs",
        sa.Column("dest_geo", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.execute("CREATE INDEX transport_legs_origin_idx ON transport_legs USING GIST (origin_geo)")
    op.execute("CREATE INDEX transport_legs_dest_idx ON transport_legs USING GIST (dest_geo)")
    op.create_index("transport_legs_user_id_idx", "transport_legs", ["user_id"])
    op.create_index("transport_legs_trip_id_idx", "transport_legs", ["trip_id"])

    # --- accommodations ---
    op.add_column(
        "accommodations",
        sa.Column("destination_id", UUID(as_uuid=True), sa.ForeignKey("destinations.id", ondelete="SET NULL"), nullable=True),
    )
    op.add_column("accommodations", sa.Column("type", sa.String, nullable=True))
    op.add_column("accommodations", sa.Column("address", sa.Text, nullable=True))
    op.add_column(
        "accommodations",
        sa.Column("location", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.add_column("accommodations", sa.Column("check_in", sa.DateTime(timezone=True), nullable=True))
    op.add_column("accommodations", sa.Column("check_out", sa.DateTime(timezone=True), nullable=True))
    op.add_column("accommodations", sa.Column("confirmation", sa.String, nullable=True))
    op.add_column("accommodations", sa.Column("cost_per_night", sa.Numeric(10, 2), nullable=True))
    op.add_column("accommodations", sa.Column("currency", sa.String(3), nullable=False, server_default="USD"))
    op.add_column("accommodations", sa.Column("rating", sa.SmallInteger, nullable=True))
    op.add_column("accommodations", sa.Column("notes", sa.Text, nullable=True))
    op.create_index("accommodations_user_id_idx", "accommodations", ["user_id"])
    op.create_index("accommodations_trip_id_idx", "accommodations", ["trip_id"])


def downgrade() -> None:
    op.drop_index("accommodations_trip_id_idx", table_name="accommodations")
    op.drop_index("accommodations_user_id_idx", table_name="accommodations")
    for col in ["notes", "rating", "currency", "cost_per_night", "confirmation",
                "check_out", "check_in", "location", "address", "type", "destination_id"]:
        op.drop_column("accommodations", col)

    op.drop_index("transport_legs_trip_id_idx", table_name="transport_legs")
    op.drop_index("transport_legs_user_id_idx", table_name="transport_legs")
    op.execute("DROP INDEX IF EXISTS transport_legs_dest_idx")
    op.execute("DROP INDEX IF EXISTS transport_legs_origin_idx")
    for col in ["dest_geo", "origin_geo", "notes", "currency", "cost", "booking_ref",
                "seat_class", "distance_km", "duration_min", "arrival_at", "departure_at",
                "dest_city", "origin_city", "dest_iata", "origin_iata", "airline", "flight_number"]:
        op.drop_column("transport_legs", col)

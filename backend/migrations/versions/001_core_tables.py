"""core tables: users, trips, destinations

Revision ID: 001
Revises:
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
import geoalchemy2

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    op.create_table(
        "users",
        sa.Column("id", sa.String, primary_key=True),
        sa.Column("email", sa.String, unique=True, nullable=False),
        sa.Column("display_name", sa.String, nullable=True),
        sa.Column("avatar_url", sa.String, nullable=True),
        sa.Column("home_country", sa.String(2), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("preferences", JSONB, server_default=sa.text("'{}'")),
    )

    op.create_table(
        "trips",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String, nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("status", sa.String, nullable=False, server_default=sa.text("'past'")),
        sa.Column("start_date", sa.Date, nullable=True),
        sa.Column("end_date", sa.Date, nullable=True),
        sa.Column("cover_photo_id", UUID(as_uuid=True), nullable=True),  # FK → photos.id added Phase 2
        sa.Column("tags", ARRAY(sa.String), server_default=sa.text("'{}'")),
        sa.Column("visibility", sa.String, nullable=False, server_default=sa.text("'private'")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("trips_user_id_idx", "trips", ["user_id"])

    op.create_table(
        "destinations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("city", sa.String, nullable=False),
        sa.Column("country_code", sa.String(2), nullable=False),
        sa.Column("country_name", sa.String, nullable=False),
        sa.Column("region", sa.String, nullable=True),
        sa.Column("location", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
        sa.Column("arrival_date", sa.Date, nullable=True),
        sa.Column("departure_date", sa.Date, nullable=True),
        sa.Column("nights", sa.Integer, nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("rating", sa.SmallInteger, nullable=True),
        sa.Column("order_index", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("destinations_user_id_idx", "destinations", ["user_id"])
    op.create_index("destinations_trip_id_idx", "destinations", ["trip_id"])
    op.execute("CREATE INDEX destinations_location_idx ON destinations USING GIST (location)")


def downgrade() -> None:
    op.drop_table("destinations")
    op.drop_table("trips")
    op.drop_table("users")

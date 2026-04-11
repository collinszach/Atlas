"""photos table + trips.cover_photo_id FK

Revision ID: 004
Revises: 003
Create Date: 2026-04-11
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "photos",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            sa.String,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "trip_id",
            UUID(as_uuid=True),
            sa.ForeignKey("trips.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "destination_id",
            UUID(as_uuid=True),
            sa.ForeignKey("destinations.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("storage_key", sa.String, nullable=False),
        sa.Column("thumbnail_key", sa.String, nullable=True),
        sa.Column("original_filename", sa.String, nullable=True),
        sa.Column("caption", sa.Text, nullable=True),
        sa.Column("taken_at", sa.String, nullable=True),
        sa.Column("latitude", sa.String, nullable=True),
        sa.Column("longitude", sa.String, nullable=True),
        sa.Column("width", sa.Integer, nullable=True),
        sa.Column("height", sa.Integer, nullable=True),
        sa.Column("size_bytes", sa.BigInteger, nullable=True),
        sa.Column("is_cover", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("order_index", sa.Integer, nullable=True),
        sa.Column(
            "created_at",
            sa.String,
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("photos_user_id_idx", "photos", ["user_id"])
    op.create_index("photos_trip_id_idx", "photos", ["trip_id"])

    # Add FK from trips.cover_photo_id → photos.id (deferred to allow circular insert)
    op.create_foreign_key(
        "fk_trips_cover_photo_id",
        "trips",
        "photos",
        ["cover_photo_id"],
        ["id"],
        ondelete="SET NULL",
        use_alter=True,
        deferrable=True,
        initially="DEFERRED",
    )


def downgrade() -> None:
    op.drop_constraint("fk_trips_cover_photo_id", "trips", type_="foreignkey")
    op.drop_table("photos")

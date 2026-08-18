"""repoint photos from trips/destinations to transport_legs (flights)

Revision ID: 012
Revises: 011
Create Date: 2026-08-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("fk_trips_cover_photo_id", "trips", type_="foreignkey")
    op.drop_column("trips", "cover_photo_id")

    op.add_column(
        "photos",
        sa.Column(
            "transport_leg_id",
            UUID(as_uuid=True),
            sa.ForeignKey("transport_legs.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.create_index("photos_transport_leg_id_idx", "photos", ["transport_leg_id"])

    op.drop_index("photos_trip_id_idx", table_name="photos")
    op.drop_constraint("photos_trip_id_fkey", "photos", type_="foreignkey")
    op.drop_column("photos", "trip_id")
    op.drop_constraint("photos_destination_id_fkey", "photos", type_="foreignkey")
    op.drop_column("photos", "destination_id")

    op.alter_column("photos", "transport_leg_id", nullable=False)


def downgrade() -> None:
    op.alter_column("photos", "transport_leg_id", nullable=True)

    op.add_column(
        "photos",
        sa.Column("destination_id", UUID(as_uuid=True), sa.ForeignKey("destinations.id", ondelete="SET NULL"), nullable=True),
    )
    op.add_column(
        "photos",
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=True),
    )
    op.create_index("photos_trip_id_idx", "photos", ["trip_id"])

    op.drop_index("photos_transport_leg_id_idx", table_name="photos")
    op.drop_column("photos", "transport_leg_id")

    op.add_column("trips", sa.Column("cover_photo_id", UUID(as_uuid=True), nullable=True))
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

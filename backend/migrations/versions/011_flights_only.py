"""trim transport_legs to standalone flights (drop non-flight type, trip_id FK)

Revision ID: 011
Revises: 010
Create Date: 2026-08-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index("transport_legs_trip_id_idx", table_name="transport_legs")
    op.drop_constraint("transport_legs_trip_id_fkey", "transport_legs", type_="foreignkey")
    op.drop_column("transport_legs", "trip_id")
    op.drop_column("transport_legs", "type")


def downgrade() -> None:
    op.add_column(
        "transport_legs",
        sa.Column("type", sa.String, nullable=False, server_default=sa.text("'flight'")),
    )
    op.add_column(
        "transport_legs",
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=True),
    )
    op.create_index("transport_legs_trip_id_idx", "transport_legs", ["trip_id"])

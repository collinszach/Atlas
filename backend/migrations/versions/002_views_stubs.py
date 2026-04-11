"""country_visits materialized view and stub tables

Revision ID: 002
Revises: 001
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE MATERIALIZED VIEW country_visits AS
        SELECT
          d.user_id,
          d.country_code,
          MAX(d.country_name)               AS country_name,
          COUNT(DISTINCT d.trip_id)         AS visit_count,
          MIN(d.arrival_date)               AS first_visit,
          MAX(d.departure_date)             AS last_visit,
          COALESCE(SUM(d.nights), 0)        AS total_nights,
          ARRAY_AGG(DISTINCT d.trip_id)     AS trip_ids
        FROM destinations d
        GROUP BY d.user_id, d.country_code
    """)
    op.execute("CREATE UNIQUE INDEX country_visits_uid_cc ON country_visits(user_id, country_code)")

    op.create_table(
        "transport_legs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String, nullable=False, server_default=sa.text("'flight'")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "accommodations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )


def downgrade() -> None:
    op.drop_table("accommodations")
    op.drop_table("transport_legs")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS country_visits")

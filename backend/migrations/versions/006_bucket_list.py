"""add bucket_list table

Revision ID: 006
Revises: 005
Create Date: 2026-04-12
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bucket_list",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("country_code", sa.String(2), nullable=True),
        sa.Column("country_name", sa.String, nullable=True),
        sa.Column("city", sa.String, nullable=True),
        sa.Column("priority", sa.SmallInteger, nullable=False, server_default="3"),
        sa.Column("reason", sa.Text, nullable=True),
        sa.Column("ideal_season", sa.String, nullable=True),
        sa.Column("estimated_cost", sa.Numeric(10, 2), nullable=True),
        sa.Column("trip_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("trips.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_check_constraint(
        "bucket_list_priority_check", "bucket_list", "priority BETWEEN 1 AND 5"
    )
    op.create_check_constraint(
        "bucket_list_season_check", "bucket_list",
        "ideal_season IN ('spring','summer','fall','winter','any')"
    )


def downgrade() -> None:
    op.drop_table("bucket_list")

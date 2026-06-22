"""add skywatch tables (devices, preferences, alerts, notable types, mil callsigns)

Revision ID: 008
Revises: 007
Create Date: 2026-06-13
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "skywatch_devices",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("apns_token", sa.String, nullable=True),
        sa.Column("platform", sa.String, nullable=False, server_default="ios"),
        sa.Column("last_lat", sa.Numeric(9, 6), nullable=True),
        sa.Column("last_lng", sa.Numeric(9, 6), nullable=True),
        sa.Column("last_seen", sa.DateTime(timezone=True), nullable=True),
        sa.Column("push_enabled", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "skywatch_preferences",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, unique=True, index=True),
        sa.Column("notable_types_enabled", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("military_enabled", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("emergency_enabled", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("watchlist_enabled", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("radius_km", sa.Numeric(6, 2), nullable=False, server_default="30"),
        sa.Column("alt_ceiling_ft", sa.Integer, nullable=True),
        sa.Column("cooldown_minutes", sa.Integer, nullable=False, server_default="360"),
        sa.Column("quiet_hours", postgresql.JSONB, server_default=sa.text("'{}'")),
        sa.Column("watchlist", postgresql.JSONB, server_default=sa.text("'[]'")),
        sa.Column("nl_prompt", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "aircraft_alerts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("hex", sa.String(6), nullable=False, index=True),
        sa.Column("callsign", sa.String, nullable=True),
        sa.Column("type", sa.String, nullable=True),
        sa.Column("registration", sa.String, nullable=True),
        sa.Column("trigger", sa.String, nullable=False),
        sa.Column("score", sa.SmallInteger, nullable=False, server_default="0"),
        sa.Column("message", sa.Text, nullable=True),
        sa.Column("lat", sa.Numeric(9, 6), nullable=True),
        sa.Column("lng", sa.Numeric(9, 6), nullable=True),
        sa.Column("alt_baro", sa.Integer, nullable=True),
        sa.Column("distance_km", sa.Numeric(8, 2), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "notable_types",
        sa.Column("type_code", sa.String(10), primary_key=True),
        sa.Column("description", sa.String, nullable=False),
        sa.Column("rarity_tier", sa.SmallInteger, nullable=False, server_default="1"),
    )

    op.create_table(
        "mil_callsign_prefixes",
        sa.Column("prefix", sa.String(10), primary_key=True),
        sa.Column("description", sa.String, nullable=False),
    )


def downgrade() -> None:
    op.drop_table("mil_callsign_prefixes")
    op.drop_table("notable_types")
    op.drop_table("aircraft_alerts")
    op.drop_table("skywatch_preferences")
    op.drop_table("skywatch_devices")

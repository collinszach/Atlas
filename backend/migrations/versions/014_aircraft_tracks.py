"""add aircraft_tracks + alert engagement columns

Phase 0 of the prediction work: Atlas currently discards every ADS-B position it
polls, so ETA, route inference and rule tuning have nothing to learn from. This
starts retaining observations and recording whether alerts were acted on.

Revision ID: 014
Revises: 013
Create Date: 2026-09-20
"""
from alembic import op
import sqlalchemy as sa

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "aircraft_tracks",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("hex", sa.String(6), nullable=False),
        sa.Column("seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("callsign", sa.String, nullable=True),
        sa.Column("registration", sa.String, nullable=True),
        sa.Column("type", sa.String, nullable=True),
        sa.Column("lat", sa.Numeric(9, 6), nullable=True),
        sa.Column("lng", sa.Numeric(9, 6), nullable=True),
        sa.Column("alt_baro", sa.Integer, nullable=True),
        sa.Column("ground_speed", sa.Numeric(7, 2), nullable=True),
        sa.Column("track_deg", sa.Numeric(5, 2), nullable=True),
        sa.Column("squawk", sa.String(4), nullable=True),
        sa.Column("is_military", sa.Boolean, nullable=False, server_default=sa.text("false")),
    )

    # Collapses concurrent observers of the same aircraft in the same cycle.
    op.create_unique_constraint(
        "aircraft_tracks_hex_seen_at_key", "aircraft_tracks", ["hex", "seen_at"]
    )
    # Replaying one aircraft's history (route inference, ETA).
    op.create_index(
        "aircraft_tracks_hex_seen_idx", "aircraft_tracks", ["hex", "seen_at"]
    )
    # Retention pruning, which scans by age alone.
    op.create_index("aircraft_tracks_seen_at_idx", "aircraft_tracks", ["seen_at"])
    # Callsign-keyed historical lookups for route inference.
    op.create_index(
        "aircraft_tracks_callsign_idx",
        "aircraft_tracks",
        ["callsign"],
        postgresql_where=sa.text("callsign IS NOT NULL"),
    )

    op.add_column(
        "aircraft_alerts",
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "aircraft_alerts",
        sa.Column("dismissed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("aircraft_alerts", "dismissed_at")
    op.drop_column("aircraft_alerts", "opened_at")
    op.drop_index("aircraft_tracks_callsign_idx", table_name="aircraft_tracks")
    op.drop_index("aircraft_tracks_seen_at_idx", table_name="aircraft_tracks")
    op.drop_index("aircraft_tracks_hex_seen_idx", table_name="aircraft_tracks")
    op.drop_constraint("aircraft_tracks_hex_seen_at_key", "aircraft_tracks", type_="unique")
    op.drop_table("aircraft_tracks")

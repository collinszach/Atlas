"""widen hex columns for non-ICAO (TIS-B) addresses

ADS-B feeds prefix non-ICAO addresses — TIS-B and ADS-R targets — with "~", so
"~ab1234" is seven characters against a VARCHAR(6). Collection died on it:
observations are written as one multi-row INSERT, so a single TIS-B target in
the batch discarded the whole cycle. Over a busy area that is most cycles,
which is why aircraft_tracks stopped growing.

aircraft_alerts.hex carried the same latent bug; it simply had not been hit yet
because alerts fire on notable aircraft, which usually broadcast a real ICAO
address.

Revision ID: 015
Revises: 014
Create Date: 2026-09-21
"""
from alembic import op
import sqlalchemy as sa

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "aircraft_tracks", "hex",
        existing_type=sa.String(6), type_=sa.String(12), existing_nullable=False,
    )
    op.alter_column(
        "aircraft_alerts", "hex",
        existing_type=sa.String(6), type_=sa.String(12), existing_nullable=False,
    )


def downgrade() -> None:
    # Truncating back to 6 would corrupt any "~"-prefixed address already stored,
    # so clear those rows rather than silently mangling identifiers.
    op.execute("DELETE FROM aircraft_tracks WHERE length(hex) > 6")
    op.execute("DELETE FROM aircraft_alerts WHERE length(hex) > 6")
    op.alter_column(
        "aircraft_alerts", "hex",
        existing_type=sa.String(12), type_=sa.String(6), existing_nullable=False,
    )
    op.alter_column(
        "aircraft_tracks", "hex",
        existing_type=sa.String(12), type_=sa.String(6), existing_nullable=False,
    )

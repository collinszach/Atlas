"""countries table for Natural Earth polygon data

Revision ID: 003
Revises: 002
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
import geoalchemy2

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "countries",
        sa.Column("code", sa.String(2), primary_key=True),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("name_long", sa.String, nullable=True),
        sa.Column("continent", sa.String, nullable=True),
        # Geometry (planar) — correct for polygon storage/rendering.
        # Cross-type spatial queries with Geography columns (e.g. destinations.location)
        # require explicit casts: ST_Within(d.location::geometry, c.geometry).
        sa.Column("geometry", geoalchemy2.Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=True),
    )
    op.execute("CREATE INDEX countries_geometry_idx ON countries USING GIST (geometry)")


def downgrade() -> None:
    op.drop_table("countries")

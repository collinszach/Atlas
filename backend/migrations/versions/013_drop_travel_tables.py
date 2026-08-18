"""drop general travel-tracker tables (trips, destinations, accommodations, bucket_list, countries)

Revision ID: 013
Revises: 012
Create Date: 2026-08-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
import geoalchemy2

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("DROP MATERIALIZED VIEW IF EXISTS country_visits")
    op.drop_table("bucket_list")
    op.drop_table("accommodations")
    op.drop_table("destinations")
    op.drop_table("trips")
    op.drop_table("countries")


def downgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String, nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("status", sa.String, nullable=False, server_default=sa.text("'past'")),
        sa.Column("start_date", sa.Date, nullable=True),
        sa.Column("end_date", sa.Date, nullable=True),
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

    op.create_table(
        "accommodations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("destination_id", UUID(as_uuid=True), sa.ForeignKey("destinations.id", ondelete="SET NULL"), nullable=True),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("type", sa.String, nullable=True),
        sa.Column("address", sa.Text, nullable=True),
        sa.Column("location", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
        sa.Column("check_in", sa.DateTime(timezone=True), nullable=True),
        sa.Column("check_out", sa.DateTime(timezone=True), nullable=True),
        sa.Column("confirmation", sa.String, nullable=True),
        sa.Column("cost_per_night", sa.Numeric(10, 2), nullable=True),
        sa.Column("currency", sa.String(3), nullable=False, server_default="USD"),
        sa.Column("rating", sa.SmallInteger, nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.execute("CREATE INDEX accommodations_location_idx ON accommodations USING GIST (location)")
    op.create_index("accommodations_user_id_idx", "accommodations", ["user_id"])
    op.create_index("accommodations_trip_id_idx", "accommodations", ["trip_id"])

    op.create_table(
        "bucket_list",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("country_code", sa.String(2), nullable=True),
        sa.Column("country_name", sa.String, nullable=True),
        sa.Column("city", sa.String, nullable=True),
        sa.Column("priority", sa.SmallInteger, nullable=False, server_default="3"),
        sa.Column("reason", sa.Text, nullable=True),
        sa.Column("ideal_season", sa.String, nullable=True),
        sa.Column("estimated_cost", sa.Numeric(10, 2), nullable=True),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="SET NULL"), nullable=True),
        sa.Column("ai_summary", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_check_constraint("bucket_list_priority_check", "bucket_list", "priority BETWEEN 1 AND 5")
    op.create_check_constraint(
        "bucket_list_season_check", "bucket_list", "ideal_season IN ('spring','summer','fall','winter','any')"
    )

    op.create_table(
        "countries",
        sa.Column("code", sa.String(2), primary_key=True),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("name_long", sa.String, nullable=True),
        sa.Column("continent", sa.String, nullable=True),
        sa.Column("geometry", geoalchemy2.Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=True),
    )
    op.execute("CREATE INDEX countries_geometry_idx ON countries USING GIST (geometry)")

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

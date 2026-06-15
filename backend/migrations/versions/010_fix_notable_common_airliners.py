"""Remove common airliners wrongly seeded as notable/rare types.

A320 and B737 are the ICAO type codes for the standard, ubiquitous Airbus A320
and Boeing 737 — not the rare ACJ320/C-40 military VIP variants the seed claimed.
They caused every commercial A320/737 (e.g. a JetBlue A320, JBU1354) to be flagged
as a notable "military VIP" aircraft. RJ85 had a wrong description (Jetstream 31).
"""

from alembic import op

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None

# (type_code, restored description) — used to re-insert on downgrade.
_REMOVED = {
    "A320": "Airbus ACJ320 (military VIP transport A320)",
    "B737": "Boeing C-40 (military VIP transport 737)",
    "RJ85": "British Aerospace Jetstream 31 (regional twin-engine)",
}


def upgrade() -> None:
    codes = ", ".join(f"'{c}'" for c in _REMOVED)
    op.execute(f"DELETE FROM notable_types WHERE type_code IN ({codes})")


def downgrade() -> None:
    for code, desc in _REMOVED.items():
        op.execute(
            f"INSERT INTO notable_types (type_code, description) VALUES ('{code}', '{desc}') "
            f"ON CONFLICT (type_code) DO NOTHING"
        )

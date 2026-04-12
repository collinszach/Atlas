"""add ai_summary to bucket_list

Revision ID: 007
Revises: 006
Create Date: 2026-04-12
"""
from alembic import op
import sqlalchemy as sa

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("bucket_list", sa.Column("ai_summary", sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column("bucket_list", "ai_summary")

"""Initial migration: create analyses, projects, and project_analyses tables.

Revision ID: 001
Revises:
Create Date: 2026-03-16 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# Alembic revision identifiers
revision: str = "001"
down_revision: str | None = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "analyses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("config", sa.Text, nullable=True),
        sa.Column("progress", sa.Text, nullable=True),
        sa.Column("result", sa.Text, nullable=True),
        sa.Column("upload_dir", sa.String(512), nullable=True),
        sa.Column("results_dir", sa.String(512), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "projects",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(256), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "project_analyses",
        sa.Column(
            "project_id",
            sa.String(36),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "analysis_id",
            sa.String(36),
            sa.ForeignKey("analyses.id", ondelete="CASCADE"),
            primary_key=True,
        ),
    )


def downgrade() -> None:
    op.drop_table("project_analyses")
    op.drop_table("projects")
    op.drop_table("analyses")

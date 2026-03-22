"""SQLAlchemy ORM models for MetaboFlow.

Uses SQLAlchemy 2.0 style with Mapped[] annotations for full type safety.
"""

from __future__ import annotations

import uuid
from datetime import datetime, UTC
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _new_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    """Registered user."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    email: Mapped[str] = mapped_column(String(256), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String(256), nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    analyses: Mapped[list[Analysis]] = relationship("Analysis", back_populates="user")


class InviteCode(Base):
    """One-time invite code for registration."""

    __tablename__ = "invite_codes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    used_by: Mapped[Optional[str]] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class Analysis(Base):
    """Persisted analysis record."""

    __tablename__ = "analyses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")

    # JSON blobs stored as TEXT (compatible with both SQLite and PostgreSQL)
    config_json: Mapped[Optional[str]] = mapped_column("config", Text, nullable=True)
    progress_json: Mapped[Optional[str]] = mapped_column("progress", Text, nullable=True)
    result_json: Mapped[Optional[str]] = mapped_column("result", Text, nullable=True)

    # Owner (optional — null for pre-auth analyses)
    user_id: Mapped[Optional[str]] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True
    )

    # File-system paths derived at creation time
    upload_dir: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    results_dir: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    # Relationships
    user: Mapped[Optional[User]] = relationship("User", back_populates="analyses")
    project_analyses: Mapped[list[ProjectAnalysis]] = relationship(
        "ProjectAnalysis", back_populates="analysis", cascade="all, delete-orphan"
    )


class Project(Base):
    """A logical grouping of analyses."""

    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    name: Mapped[str] = mapped_column(String(256), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    project_analyses: Mapped[list[ProjectAnalysis]] = relationship(
        "ProjectAnalysis", back_populates="project", cascade="all, delete-orphan"
    )


class ProjectAnalysis(Base):
    """Many-to-many join table between projects and analyses."""

    __tablename__ = "project_analyses"

    project_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("projects.id", ondelete="CASCADE"), primary_key=True
    )
    analysis_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("analyses.id", ondelete="CASCADE"), primary_key=True
    )

    project: Mapped[Project] = relationship("Project", back_populates="project_analyses")
    analysis: Mapped[Analysis] = relationship("Analysis", back_populates="project_analyses")

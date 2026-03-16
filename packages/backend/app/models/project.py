"""Pydantic models for project management."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class ProjectCreate(BaseModel):
    """Request model for creating a project."""

    name: str
    description: str | None = None


class ProjectUpdate(BaseModel):
    """Request model for updating a project (all fields optional)."""

    name: str | None = None
    description: str | None = None


class ProjectResponse(BaseModel):
    """Response model for a project."""

    id: str
    name: str
    description: str | None = None
    analysis_ids: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

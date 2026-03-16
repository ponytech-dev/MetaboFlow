"""Project management service — in-memory store."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from app.models.project import ProjectResponse


# ── In-memory store ───────────────────────────────────────────────────────────

_projects: dict[str, dict] = {}


# ── Public API ────────────────────────────────────────────────────────────────


def create_project(name: str, description: str | None = None) -> ProjectResponse:
    """Create a new project and return its response model."""
    project_id = str(uuid.uuid4())[:8]
    now = datetime.now(UTC)
    _projects[project_id] = {
        "id": project_id,
        "name": name,
        "description": description,
        "analysis_ids": [],
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }
    return _to_response(project_id)


def get_project(project_id: str) -> ProjectResponse | None:
    """Return a project by ID, or None if not found."""
    if project_id not in _projects:
        return None
    return _to_response(project_id)


def update_project(project_id: str, updates: dict) -> ProjectResponse | None:
    """Apply partial updates to a project. Returns None if not found."""
    if project_id not in _projects:
        return None
    data = _projects[project_id]
    if "name" in updates and updates["name"] is not None:
        data["name"] = updates["name"]
    if "description" in updates:
        data["description"] = updates["description"]
    data["updated_at"] = datetime.now(UTC).isoformat()
    return _to_response(project_id)


def delete_project(project_id: str) -> bool:
    """Delete a project. Returns True if deleted, False if not found."""
    if project_id not in _projects:
        return False
    del _projects[project_id]
    return True


def list_projects() -> list[ProjectResponse]:
    """Return all projects."""
    return [_to_response(pid) for pid in _projects]


def add_analysis_to_project(project_id: str, analysis_id: str) -> ProjectResponse | None:
    """Add an analysis ID to a project. Returns None if project not found."""
    if project_id not in _projects:
        return None
    data = _projects[project_id]
    if analysis_id not in data["analysis_ids"]:
        data["analysis_ids"].append(analysis_id)
        data["updated_at"] = datetime.now(UTC).isoformat()
    return _to_response(project_id)


def remove_analysis_from_project(project_id: str, analysis_id: str) -> ProjectResponse | None:
    """Remove an analysis ID from a project. Returns None if project not found."""
    if project_id not in _projects:
        return None
    data = _projects[project_id]
    if analysis_id in data["analysis_ids"]:
        data["analysis_ids"].remove(analysis_id)
        data["updated_at"] = datetime.now(UTC).isoformat()
    return _to_response(project_id)


# ── Private helpers ───────────────────────────────────────────────────────────


def _to_response(project_id: str) -> ProjectResponse:
    data = _projects[project_id]
    return ProjectResponse(
        id=data["id"],
        name=data["name"],
        description=data.get("description"),
        analysis_ids=list(data["analysis_ids"]),
        created_at=_parse_dt(data["created_at"]),
        updated_at=_parse_dt(data["updated_at"]),
    )


def _parse_dt(value: str) -> datetime:
    return datetime.fromisoformat(value)

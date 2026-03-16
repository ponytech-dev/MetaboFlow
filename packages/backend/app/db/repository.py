"""Repository layer: thin wrappers around SQLAlchemy sessions."""

from __future__ import annotations

import json
from datetime import datetime, UTC
from typing import Any

from sqlalchemy.orm import Session

from app.db.models import Analysis, Project, ProjectAnalysis


# ── Helpers ──────────────────────────────────────────────────────────────────


def _dumps(obj: Any) -> str:
    """Serialise a value to JSON string."""
    if obj is None:
        return "{}"
    if isinstance(obj, str):
        return obj
    # Pydantic models
    if hasattr(obj, "model_dump"):
        return json.dumps(obj.model_dump(mode="json"))
    return json.dumps(obj)


def _loads(text: str | None) -> dict:
    if not text:
        return {}
    try:
        return json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return {}


# ── AnalysisRepository ────────────────────────────────────────────────────────


class AnalysisRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(
        self,
        *,
        analysis_id: str,
        config: Any,
        upload_dir: str,
        results_dir: str,
    ) -> Analysis:
        """Persist a new Analysis row and return it."""
        initial_progress = {
            "analysis_id": analysis_id,
            "status": "pending",
            "current_step": 0,
            "total_steps": 7,
            "step_name": "",
            "progress_pct": 0.0,
            "message": "Analysis created",
            "started_at": None,
            "completed_at": None,
        }
        row = Analysis(
            id=analysis_id,
            status="pending",
            config_json=_dumps(config),
            progress_json=json.dumps(initial_progress),
            result_json=json.dumps(
                {
                    "analysis_id": analysis_id,
                    "status": "pending",
                    "n_features": 0,
                    "n_significant": 0,
                    "n_annotated": 0,
                    "n_pathways": 0,
                    "result_files": [],
                    "metabodata_path": None,
                }
            ),
            upload_dir=upload_dir,
            results_dir=results_dir,
        )
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return row

    def get_by_id(self, analysis_id: str) -> Analysis | None:
        return self._db.get(Analysis, analysis_id)

    def update_status(self, analysis_id: str, status: str) -> Analysis | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        row.status = status
        row.updated_at = datetime.now(UTC)
        self._db.commit()
        self._db.refresh(row)
        return row

    def update_progress(self, analysis_id: str, progress: dict) -> Analysis | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        existing = _loads(row.progress_json)
        existing.update(progress)
        row.progress_json = json.dumps(existing)
        row.status = existing.get("status", row.status)
        row.updated_at = datetime.now(UTC)
        self._db.commit()
        self._db.refresh(row)
        return row

    def update_result(self, analysis_id: str, result: dict) -> Analysis | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        existing = _loads(row.result_json)
        existing.update(result)
        row.result_json = json.dumps(existing)
        row.updated_at = datetime.now(UTC)
        self._db.commit()
        self._db.refresh(row)
        return row

    def list_all(self) -> list[Analysis]:
        return self._db.query(Analysis).order_by(Analysis.created_at.desc()).all()

    def delete(self, analysis_id: str) -> bool:
        row = self.get_by_id(analysis_id)
        if row is None:
            return False
        self._db.delete(row)
        self._db.commit()
        return True

    # Convenience accessors used by the service layer
    def get_progress_dict(self, analysis_id: str) -> dict | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        d = _loads(row.progress_json)
        # Ensure status is always in sync with the row column
        d["status"] = row.status
        return d

    def get_result_dict(self, analysis_id: str) -> dict | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        d = _loads(row.result_json)
        d["status"] = row.status
        return d

    def get_config_dict(self, analysis_id: str) -> dict | None:
        row = self.get_by_id(analysis_id)
        if row is None:
            return None
        return _loads(row.config_json)


# ── ProjectRepository ─────────────────────────────────────────────────────────


class ProjectRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(self, *, project_id: str, name: str, description: str | None = None) -> Project:
        row = Project(id=project_id, name=name, description=description)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return row

    def get_by_id(self, project_id: str) -> Project | None:
        return self._db.get(Project, project_id)

    def update(self, project_id: str, *, name: str | None = None, description: str | None = None) -> Project | None:
        row = self.get_by_id(project_id)
        if row is None:
            return None
        if name is not None:
            row.name = name
        if description is not None:
            row.description = description
        row.updated_at = datetime.now(UTC)
        self._db.commit()
        self._db.refresh(row)
        return row

    def list_all(self) -> list[Project]:
        return self._db.query(Project).order_by(Project.created_at.desc()).all()

    def delete(self, project_id: str) -> bool:
        row = self.get_by_id(project_id)
        if row is None:
            return False
        self._db.delete(row)
        self._db.commit()
        return True

    def add_analysis(self, project_id: str, analysis_id: str) -> bool:
        """Link an analysis to a project; idempotent."""
        existing = (
            self._db.query(ProjectAnalysis)
            .filter_by(project_id=project_id, analysis_id=analysis_id)
            .first()
        )
        if existing:
            return False
        link = ProjectAnalysis(project_id=project_id, analysis_id=analysis_id)
        self._db.add(link)
        self._db.commit()
        return True

    def remove_analysis(self, project_id: str, analysis_id: str) -> bool:
        link = (
            self._db.query(ProjectAnalysis)
            .filter_by(project_id=project_id, analysis_id=analysis_id)
            .first()
        )
        if link is None:
            return False
        self._db.delete(link)
        self._db.commit()
        return True

    def list_analyses(self, project_id: str) -> list[Analysis]:
        """Return all Analysis rows linked to this project."""
        links = (
            self._db.query(ProjectAnalysis)
            .filter_by(project_id=project_id)
            .all()
        )
        ids = [lnk.analysis_id for lnk in links]
        if not ids:
            return []
        return self._db.query(Analysis).filter(Analysis.id.in_(ids)).all()

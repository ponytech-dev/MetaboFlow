"""Analysis orchestration service backed by SQLAlchemy.

Public API is identical to the previous in-memory version so that existing
routes and tests require no changes.
"""

from __future__ import annotations

import uuid
from contextlib import contextmanager
from datetime import datetime, UTC
from pathlib import Path
from typing import Generator

from app.config import settings
from app.db.base import SessionLocal
from app.db.repository import AnalysisRepository
from app.models.analysis import (
    AnalysisConfig,
    AnalysisProgress,
    AnalysisResult,
    AnalysisStatus,
)


# ── Internal helpers ──────────────────────────────────────────────────────────


@contextmanager
def _session() -> Generator[AnalysisRepository, None, None]:
    """Yield a repository and close its session on exit."""
    session = SessionLocal()
    try:
        yield AnalysisRepository(session)
    finally:
        session.close()


# ── Public API ────────────────────────────────────────────────────────────────


def create_analysis(config: AnalysisConfig, user_id: str | None = None) -> str:
    """Create a new analysis and return its 8-character ID."""
    analysis_id = str(uuid.uuid4())[:8]

    # Create data directories on disk
    upload_dir = Path(settings.upload_dir) / analysis_id
    results_dir = Path(settings.results_dir) / analysis_id
    upload_dir.mkdir(parents=True, exist_ok=True)
    results_dir.mkdir(parents=True, exist_ok=True)

    with _session() as repo:
        repo.create(
            analysis_id=analysis_id,
            config=config,
            upload_dir=str(upload_dir),
            results_dir=str(results_dir),
            user_id=user_id,
        )
    return analysis_id


def get_progress(analysis_id: str) -> AnalysisProgress | None:
    """Get current progress of an analysis."""
    with _session() as repo:
        data = repo.get_progress_dict(analysis_id)
    if data is None:
        return None

    return AnalysisProgress(
        analysis_id=data.get("analysis_id", analysis_id),
        status=AnalysisStatus(data.get("status", "pending")),
        current_step=data.get("current_step", 0),
        total_steps=data.get("total_steps", 7),
        step_name=data.get("step_name", ""),
        progress_pct=data.get("progress_pct", 0.0),
        message=data.get("message", ""),
        started_at=_parse_dt(data.get("started_at")),
        completed_at=_parse_dt(data.get("completed_at")),
    )


def get_result(analysis_id: str) -> AnalysisResult | None:
    """Get analysis results."""
    with _session() as repo:
        data = repo.get_result_dict(analysis_id)
    if data is None:
        return None

    return AnalysisResult(
        analysis_id=data.get("analysis_id", analysis_id),
        status=AnalysisStatus(data.get("status", "pending")),
        n_features=data.get("n_features", 0),
        n_significant=data.get("n_significant", 0),
        n_annotated=data.get("n_annotated", 0),
        n_pathways=data.get("n_pathways", 0),
        result_files=data.get("result_files", []),
        metabodata_path=data.get("metabodata_path"),
    )


def get_upload_dir(analysis_id: str) -> str | None:
    """Return the upload directory path for an analysis, or None if not found."""
    with _session() as repo:
        row = repo.get_by_id(analysis_id)
        return row.upload_dir if row is not None else None


def update_progress(
    analysis_id: str,
    *,
    status: AnalysisStatus | None = None,
    current_step: int | None = None,
    step_name: str | None = None,
    progress_pct: float | None = None,
    message: str | None = None,
) -> None:
    """Update analysis progress (called by Celery tasks)."""
    with _session() as repo:
        data = repo.get_progress_dict(analysis_id)
        if data is None:
            return

        patch: dict = {}

        if status is not None:
            patch["status"] = status.value if isinstance(status, AnalysisStatus) else status
            if status == AnalysisStatus.RUNNING and data.get("started_at") is None:
                patch["started_at"] = datetime.now(UTC).isoformat()
            if status in (AnalysisStatus.COMPLETED, AnalysisStatus.FAILED):
                patch["completed_at"] = datetime.now(UTC).isoformat()

        if current_step is not None:
            patch["current_step"] = current_step
        if step_name is not None:
            patch["step_name"] = step_name
        if progress_pct is not None:
            patch["progress_pct"] = progress_pct
        if message is not None:
            patch["message"] = message

        repo.update_progress(analysis_id, patch)


def update_result(
    analysis_id: str,
    *,
    n_features: int = 0,
    n_significant: int = 0,
    n_annotated: int = 0,
    n_pathways: int = 0,
    result_files: list[str] | None = None,
    metabodata_path: str | None = None,
) -> None:
    """Write analysis results to DB (called by Celery tasks after each step)."""
    with _session() as repo:
        repo.update_result(analysis_id, {
            "n_features": n_features,
            "n_significant": n_significant,
            "n_annotated": n_annotated,
            "n_pathways": n_pathways,
            "result_files": result_files or [],
            "metabodata_path": metabodata_path,
        })


def list_analyses(user_id: str | None = None) -> list[AnalysisProgress]:
    """List all analyses using a single session."""
    with _session() as repo:
        rows = repo.list_all(user_id=user_id)
        result = []
        for row in rows:
            data = repo.get_progress_dict(row.id)
            if data is None:
                continue
            result.append(
                AnalysisProgress(
                    analysis_id=data.get("analysis_id", row.id),
                    status=AnalysisStatus(data.get("status", "pending")),
                    current_step=data.get("current_step", 0),
                    total_steps=data.get("total_steps", 7),
                    step_name=data.get("step_name", ""),
                    progress_pct=data.get("progress_pct", 0.0),
                    message=data.get("message", ""),
                    started_at=_parse_dt(data.get("started_at")),
                    completed_at=_parse_dt(data.get("completed_at")),
                )
            )
    return result


# ── Private helpers ───────────────────────────────────────────────────────────


def _parse_dt(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None

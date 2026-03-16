"""Analysis orchestration service.

Manages the full analysis pipeline: file upload → peak detection →
QC → statistics → annotation → pathway → export.
"""

from __future__ import annotations

import uuid
from datetime import datetime, UTC
from pathlib import Path
from typing import Any

from app.config import settings
from app.models.analysis import (
    AnalysisConfig,
    AnalysisProgress,
    AnalysisResult,
    AnalysisStatus,
)

# In-memory store (will be replaced by PostgreSQL in production)
_analyses: dict[str, dict[str, Any]] = {}


def create_analysis(config: AnalysisConfig) -> str:
    """Create a new analysis and return its ID."""
    analysis_id = str(uuid.uuid4())[:8]

    # Create data directories
    upload_dir = Path(settings.upload_dir) / analysis_id
    results_dir = Path(settings.results_dir) / analysis_id
    upload_dir.mkdir(parents=True, exist_ok=True)
    results_dir.mkdir(parents=True, exist_ok=True)

    _analyses[analysis_id] = {
        "id": analysis_id,
        "config": config,
        "status": AnalysisStatus.PENDING,
        "current_step": 0,
        "step_name": "",
        "progress_pct": 0.0,
        "message": "Analysis created",
        "started_at": None,
        "completed_at": None,
        "upload_dir": str(upload_dir),
        "results_dir": str(results_dir),
        "result_files": [],
        "n_features": 0,
        "n_significant": 0,
        "n_annotated": 0,
        "n_pathways": 0,
    }

    return analysis_id


def get_progress(analysis_id: str) -> AnalysisProgress | None:
    """Get current progress of an analysis."""
    data = _analyses.get(analysis_id)
    if data is None:
        return None

    return AnalysisProgress(
        analysis_id=data["id"],
        status=data["status"],
        current_step=data["current_step"],
        total_steps=7,
        step_name=data["step_name"],
        progress_pct=data["progress_pct"],
        message=data["message"],
        started_at=data["started_at"],
        completed_at=data["completed_at"],
    )


def get_result(analysis_id: str) -> AnalysisResult | None:
    """Get analysis results."""
    data = _analyses.get(analysis_id)
    if data is None:
        return None

    return AnalysisResult(
        analysis_id=data["id"],
        status=data["status"],
        n_features=data["n_features"],
        n_significant=data["n_significant"],
        n_annotated=data["n_annotated"],
        n_pathways=data["n_pathways"],
        result_files=data["result_files"],
        metabodata_path=None,
    )


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
    data = _analyses.get(analysis_id)
    if data is None:
        return

    if status is not None:
        data["status"] = status
        if status == AnalysisStatus.RUNNING and data["started_at"] is None:
            data["started_at"] = datetime.now(UTC)
        if status in (AnalysisStatus.COMPLETED, AnalysisStatus.FAILED):
            data["completed_at"] = datetime.now(UTC)

    if current_step is not None:
        data["current_step"] = current_step
    if step_name is not None:
        data["step_name"] = step_name
    if progress_pct is not None:
        data["progress_pct"] = progress_pct
    if message is not None:
        data["message"] = message


def list_analyses() -> list[AnalysisProgress]:
    """List all analyses."""
    return [
        get_progress(aid)
        for aid in _analyses
        if get_progress(aid) is not None
    ]

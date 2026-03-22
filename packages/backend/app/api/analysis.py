"""Analysis API routes with user_id data isolation."""

from __future__ import annotations

import asyncio
import json
from typing import AsyncGenerator, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sse_starlette.sse import EventSourceResponse

from app.middleware.auth import get_optional_user
from app.db.models import User
from app.models.analysis import (
    AnalysisConfig,
    AnalysisProgress,
    AnalysisResult,
)
from app.services import analysis_service

router = APIRouter(prefix="/analyses", tags=["analyses"])


def _verify_ownership(analysis_id: str, user: Optional[User]) -> None:
    """Verify the current user owns this analysis. Skip if no auth."""
    if user is None:
        return
    from app.db.base import SessionLocal
    from app.db.models import Analysis
    session = SessionLocal()
    try:
        record = session.query(Analysis).filter_by(id=analysis_id).first()
        if record is None:
            raise HTTPException(status_code=404, detail="Analysis not found")
        if record.user_id is not None and record.user_id != user.id:
            raise HTTPException(status_code=403, detail="Access denied")
    finally:
        session.close()


@router.post("", response_model=dict)
async def create_analysis(
    config: AnalysisConfig,
    user: Optional[User] = Depends(get_optional_user),
) -> dict:
    """Create a new analysis pipeline run."""
    user_id = user.id if user else None
    analysis_id = analysis_service.create_analysis(config, user_id=user_id)
    return {"analysis_id": analysis_id, "message": "Analysis created"}


@router.post("/{analysis_id}/upload")
async def upload_files(
    analysis_id: str,
    files: list[UploadFile],
    user: Optional[User] = Depends(get_optional_user),
) -> dict:
    """Upload mzML/mzXML files for an analysis."""
    _verify_ownership(analysis_id, user)

    upload_dir = analysis_service.get_upload_dir(analysis_id)
    if upload_dir is None:
        raise HTTPException(status_code=404, detail="Analysis not found")

    saved_files = []
    for f in files:
        if f.filename is None:
            continue
        file_path = f"{upload_dir}/{f.filename}"
        content = await f.read()
        with open(file_path, "wb") as out:
            out.write(content)
        saved_files.append(f.filename)

    return {"uploaded": saved_files, "count": len(saved_files)}


@router.post("/{analysis_id}/start")
async def start_analysis(
    analysis_id: str,
    user: Optional[User] = Depends(get_optional_user),
) -> dict:
    """Start the analysis pipeline (dispatches Celery task)."""
    _verify_ownership(analysis_id, user)

    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Analysis not found")

    from app.tasks.analysis_tasks import run_analysis_pipeline
    from app.db.base import SessionLocal
    from app.db.models import Analysis

    session = SessionLocal()
    try:
        record = session.query(Analysis).filter_by(id=analysis_id).first()
        config_dict = json.loads(record.config_json) if record and record.config_json else {}
    finally:
        session.close()

    run_analysis_pipeline.delay(analysis_id, config_dict)
    return {"analysis_id": analysis_id, "message": "Analysis started"}


@router.get("/{analysis_id}/progress", response_model=AnalysisProgress)
async def get_progress(
    analysis_id: str,
    user: Optional[User] = Depends(get_optional_user),
) -> AnalysisProgress:
    """Get current analysis progress."""
    _verify_ownership(analysis_id, user)
    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return progress


@router.get("/{analysis_id}/progress/stream")
async def stream_progress(
    analysis_id: str,
    user: Optional[User] = Depends(get_optional_user),
) -> EventSourceResponse:
    """SSE stream for real-time analysis progress updates."""
    _verify_ownership(analysis_id, user)

    async def event_generator() -> AsyncGenerator[dict, None]:
        last_pct = -1.0
        while True:
            progress = analysis_service.get_progress(analysis_id)
            if progress is None:
                yield {"event": "error", "data": json.dumps({"error": "Analysis not found"})}
                break

            if progress.progress_pct != last_pct:
                last_pct = progress.progress_pct
                yield {"event": "progress", "data": progress.model_dump_json()}

            if progress.status in ("completed", "failed"):
                yield {"event": "done", "data": progress.model_dump_json()}
                break

            await asyncio.sleep(1)

    return EventSourceResponse(event_generator())


@router.get("/{analysis_id}/result", response_model=AnalysisResult)
async def get_result(
    analysis_id: str,
    user: Optional[User] = Depends(get_optional_user),
) -> AnalysisResult:
    """Get analysis results."""
    _verify_ownership(analysis_id, user)
    result = analysis_service.get_result(analysis_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return result


@router.get("", response_model=list[AnalysisProgress])
async def list_analyses(
    user: Optional[User] = Depends(get_optional_user),
) -> list[AnalysisProgress]:
    """List analyses for current user."""
    user_id = user.id if user else None
    return analysis_service.list_analyses(user_id=user_id)

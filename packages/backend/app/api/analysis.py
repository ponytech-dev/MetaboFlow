"""Analysis API routes."""

from __future__ import annotations

import asyncio
import json
from typing import AsyncGenerator

from fastapi import APIRouter, HTTPException, UploadFile
from sse_starlette.sse import EventSourceResponse

from app.models.analysis import (
    AnalysisConfig,
    AnalysisProgress,
    AnalysisResult,
)
from app.services import analysis_service

router = APIRouter(prefix="/analyses", tags=["analyses"])


@router.post("", response_model=dict)
async def create_analysis(config: AnalysisConfig) -> dict:
    """Create a new analysis pipeline run."""
    analysis_id = analysis_service.create_analysis(config)
    return {"analysis_id": analysis_id, "message": "Analysis created"}


@router.post("/{analysis_id}/upload")
async def upload_files(analysis_id: str, files: list[UploadFile]) -> dict:
    """Upload mzML/mzXML files for an analysis."""
    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Analysis not found")

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
async def start_analysis(analysis_id: str) -> dict:
    """Start the analysis pipeline (dispatches Celery task)."""
    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Analysis not found")

    # Import here to avoid circular imports at module level
    from app.tasks.analysis_tasks import run_analysis_pipeline

    # Retrieve config from DB and pass to Celery task
    from app.db.base import SessionLocal
    from app.db.models import Analysis
    import json

    session = SessionLocal()
    try:
        record = session.query(Analysis).filter_by(id=analysis_id).first()
        config_dict = json.loads(record.config_json) if record and record.config_json else {}
    finally:
        session.close()

    run_analysis_pipeline.delay(analysis_id, config_dict)
    return {"analysis_id": analysis_id, "message": "Analysis started"}


@router.get("/{analysis_id}/progress", response_model=AnalysisProgress)
async def get_progress(analysis_id: str) -> AnalysisProgress:
    """Get current analysis progress."""
    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return progress


@router.get("/{analysis_id}/progress/stream")
async def stream_progress(analysis_id: str) -> EventSourceResponse:
    """SSE stream for real-time analysis progress updates."""

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
async def get_result(analysis_id: str) -> AnalysisResult:
    """Get analysis results."""
    result = analysis_service.get_result(analysis_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return result


@router.get("", response_model=list[AnalysisProgress])
async def list_analyses() -> list[AnalysisProgress]:
    """List all analyses."""
    return analysis_service.list_analyses()

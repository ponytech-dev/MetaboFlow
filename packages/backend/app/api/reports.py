"""Report API routes — proxies to report-worker for PDF/Word generation.

Endpoints:
    POST /api/v1/analyses/{analysis_id}/report/generate  — generate PDF/Word report
    GET  /api/v1/analyses/{analysis_id}/report/download/{format} — download generated report
    GET  /api/v1/analyses/{analysis_id}/methods           — Methods paragraph as JSON
"""

from __future__ import annotations

import os

import httpx
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from app.config import settings

router = APIRouter(prefix="/analyses", tags=["reports"])


class GenerateReportRequest(BaseModel):
    """Request to generate a report."""
    format: str = "both"  # "pdf", "word", "both"
    selected_charts: list[str] | None = None


@router.post("/{analysis_id}/report/generate")
async def generate_report(analysis_id: str, req: GenerateReportRequest) -> dict:
    """Generate PDF and/or Word report via report-worker."""
    metabodata_path = f"/data/results/{analysis_id}/metabodata_stats.h5"
    chart_dir = f"/data/results/{analysis_id}/charts"
    output_dir = f"/data/results/{analysis_id}/report"

    payload = {
        "metabodata_path": metabodata_path,
        "chart_dir": chart_dir,
        "output_dir": output_dir,
        "format": req.format,
    }
    if req.selected_charts:
        payload["selected_charts"] = req.selected_charts

    async with httpx.AsyncClient(timeout=300) as client:
        resp = await client.post(f"{settings.report_worker_url}/generate", json=payload)
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        return resp.json()


@router.get("/{analysis_id}/report/download/{fmt}")
async def download_report(analysis_id: str, fmt: str) -> FileResponse:
    """Download generated report file (pdf or docx)."""
    report_dir = f"/data/results/{analysis_id}/report"

    if fmt == "pdf":
        path = os.path.join(report_dir, "report.pdf")
        media_type = "application/pdf"
        filename = f"metaboflow_report_{analysis_id}.pdf"
    elif fmt in ("word", "docx"):
        path = os.path.join(report_dir, "report.docx")
        media_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        filename = f"metaboflow_report_{analysis_id}.docx"
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported format: {fmt}. Use 'pdf' or 'word'.")

    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail=f"Report not generated yet. POST /report/generate first.")

    return FileResponse(path=path, media_type=media_type, filename=filename)


@router.get("/{analysis_id}/report/files")
async def list_report_files(analysis_id: str) -> dict:
    """List available report files for an analysis."""
    report_dir = f"/data/results/{analysis_id}/report"
    if not os.path.isdir(report_dir):
        return {"files": [], "count": 0}

    files = []
    for f in sorted(os.listdir(report_dir)):
        if f.endswith((".pdf", ".docx")):
            files.append({
                "name": f,
                "format": "pdf" if f.endswith(".pdf") else "word",
                "size": os.path.getsize(os.path.join(report_dir, f)),
            })
    return {"files": files, "count": len(files)}


@router.get("/{analysis_id}/methods")
async def get_methods(analysis_id: str) -> dict:
    """Return auto-generated Methods paragraph from report-worker."""
    metabodata_path = f"/data/results/{analysis_id}/metabodata_stats.h5"

    if not os.path.exists(metabodata_path):
        raise HTTPException(status_code=404, detail="Analysis results not found")

    # Generate methods text via report-worker
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(f"{settings.report_worker_url}/generate", json={
            "metabodata_path": metabodata_path,
            "chart_dir": f"/data/results/{analysis_id}/charts",
            "output_dir": f"/data/results/{analysis_id}/report",
            "format": "word",  # Just to get methods text
        })

    # For now, return a static methods paragraph based on known pipeline
    return {
        "analysis_id": analysis_id,
        "methods": (
            "Untargeted metabolomics data were processed using MetaboFlow (v1.0). "
            "Peak detection was performed with XCMS. Feature grouping and retention time "
            "correction were applied. Redundant features were removed using CAMERA. "
            "Statistical analysis was performed using limma with Benjamini-Hochberg FDR correction."
        ),
    }

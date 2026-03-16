"""Report API routes.

Endpoints:
    GET /api/v1/analyses/{analysis_id}/report          — full HTML report
    GET /api/v1/analyses/{analysis_id}/report/download — HTML as attachment
    GET /api/v1/analyses/{analysis_id}/methods         — Methods paragraph as JSON
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse, Response

from app.services import report_service

router = APIRouter(prefix="/analyses", tags=["reports"])


@router.get("/{analysis_id}/report", response_class=HTMLResponse)
async def get_report(
    analysis_id: str,
    include_charts: bool = Query(default=True, description="Include chart placeholders in the report"),
) -> HTMLResponse:
    """Return a complete HTML analysis report."""
    try:
        html = report_service.generate_report(analysis_id, include_charts=include_charts)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Analysis '{analysis_id}' not found")
    return HTMLResponse(content=html, status_code=200)


@router.get("/{analysis_id}/report/download")
async def download_report(
    analysis_id: str,
    include_charts: bool = Query(default=True, description="Include chart placeholders in the report"),
) -> Response:
    """Return the HTML report as a downloadable file attachment."""
    try:
        html = report_service.generate_report(analysis_id, include_charts=include_charts)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Analysis '{analysis_id}' not found")

    filename = f"metaboflow_report_{analysis_id}.html"
    return Response(
        content=html,
        media_type="text/html",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/{analysis_id}/methods")
async def get_methods(analysis_id: str) -> dict[str, str]:
    """Return the auto-generated Methods paragraph as JSON."""
    try:
        data = report_service._get_analysis_data(analysis_id)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Analysis '{analysis_id}' not found")

    provenance = report_service._extract_provenance(data)
    paragraph = report_service.generate_methods_paragraph(provenance)
    return {"analysis_id": analysis_id, "methods": paragraph}

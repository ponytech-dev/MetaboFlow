"""Chart rendering API — proxies requests to chart-r-worker."""

from __future__ import annotations

from typing import Any

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.config import settings

router = APIRouter(prefix="/charts", tags=["charts"])


class RenderRequest(BaseModel):
    """Request to render a chart template."""
    analysis_id: str
    template_name: str
    params: dict[str, Any] = Field(default_factory=dict)


class BatchRenderRequest(BaseModel):
    """Request to render multiple chart templates."""
    analysis_id: str
    template_names: list[str]
    params: dict[str, Any] = Field(default_factory=dict)


@router.post("/render")
async def render_chart(req: RenderRequest) -> dict:
    """Render a single chart template for an analysis."""
    metabodata_path = f"/data/results/{req.analysis_id}/metabodata_stats.h5"
    output_dir = f"/data/results/{req.analysis_id}/charts"

    payload = {
        "template_name": req.template_name,
        "metabodata_path": metabodata_path,
        "output_dir": output_dir,
        "params": req.params,
    }

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(f"{settings.chart_r_worker_url}/render", json=payload)
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        return resp.json()


@router.post("/render-batch")
async def render_batch(req: BatchRenderRequest) -> dict:
    """Render multiple chart templates for an analysis."""
    results = []
    errors = []

    for name in req.template_names:
        payload = {
            "template_name": name,
            "metabodata_path": f"/data/results/{req.analysis_id}/metabodata_stats.h5",
            "output_dir": f"/data/results/{req.analysis_id}/charts",
            "params": req.params,
        }
        try:
            async with httpx.AsyncClient(timeout=120) as client:
                resp = await client.post(f"{settings.chart_r_worker_url}/render", json=payload)
                if resp.status_code == 200:
                    results.append({"template": name, "status": "success", "data": resp.json()})
                else:
                    errors.append({"template": name, "status": "error", "detail": resp.text})
        except httpx.HTTPError as e:
            errors.append({"template": name, "status": "error", "detail": str(e)})

    return {"rendered": len(results), "errors": len(errors), "results": results, "error_details": errors}


@router.get("/templates")
async def list_templates() -> dict:
    """List available chart templates from chart-r-worker."""
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(f"{settings.chart_r_worker_url}/templates")
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail="chart-r-worker unavailable")
        return resp.json()


@router.get("/templates/{name}/interpretation/{lang}")
async def get_interpretation(name: str, lang: str) -> dict:
    """Get chart interpretation text (zh or en)."""
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(f"{settings.chart_r_worker_url}/templates/{name}/interpretation/{lang}")
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        return resp.json()


@router.get("/{analysis_id}/files")
async def list_chart_files(analysis_id: str) -> dict:
    """List generated chart files for an analysis."""
    import os
    chart_dir = f"/data/results/{analysis_id}/charts"
    if not os.path.isdir(chart_dir):
        return {"files": [], "count": 0}

    files = []
    for f in sorted(os.listdir(chart_dir)):
        if f.endswith((".svg", ".pdf", ".png")):
            files.append({
                "name": f,
                "path": f"/data/results/{analysis_id}/charts/{f}",
                "format": f.rsplit(".", 1)[-1],
                "size": os.path.getsize(os.path.join(chart_dir, f)),
            })
    return {"files": files, "count": len(files)}

"""MetaboFlow Chart Service — FastAPI application.

All chart endpoints accept JSON POST bodies and return PNG images.
"""

from __future__ import annotations

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, Field

from .plots import (
    figure_to_bytes,
    plot_feature_boxplot,
    plot_heatmap,
    plot_pathway_bubble,
    plot_pca,
    plot_volcano,
)

app = FastAPI(
    title="MetaboFlow Chart Service",
    version="0.1.0",
    description="Publication-quality chart generation for MetaboFlow.",
)

_PNG = "image/png"


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class PCARequest(BaseModel):
    X: list[list[float]] = Field(..., description="Intensity matrix (n_samples × n_features)")
    groups: list[str] = Field(..., description="Group label per sample")
    title: str = Field("PCA Score Plot", description="Plot title")


class VolcanoRequest(BaseModel):
    log2fc: list[float] = Field(..., description="Log2 fold change per feature")
    pvalues: list[float] = Field(..., description="Raw p-value per feature")
    names: list[str] = Field(..., description="Feature name per feature")
    fc_cutoff: float = Field(1.0, ge=0.0, description="Absolute log2FC threshold")
    p_cutoff: float = Field(0.05, gt=0.0, le=1.0, description="P-value significance threshold")
    top_n_labels: int = Field(10, ge=0, description="Number of top features to label")


class HeatmapRequest(BaseModel):
    X: list[list[float]] = Field(..., description="Intensity matrix (n_samples × n_features)")
    sample_labels: list[str] = Field(..., description="Sample name per sample")
    feature_labels: list[str] = Field(..., description="Feature name per feature")
    groups: list[str] | None = Field(None, description="Group label per sample (optional)")
    z_score: bool = Field(True, description="Z-score normalise features before plotting")


class BoxplotRequest(BaseModel):
    intensities: list[float] = Field(..., description="Intensity values per sample")
    groups: list[str] = Field(..., description="Group label per sample")
    feature_name: str = Field("Feature", description="Feature name for plot title")


class PathwayRequest(BaseModel):
    pathway_names: list[str] = Field(..., description="Pathway display names")
    fold_enrichment: list[float] = Field(..., description="Fold enrichment per pathway")
    pvalues: list[float] = Field(..., description="Raw p-value per pathway")
    hit_counts: list[int] = Field(..., description="Hit count per pathway")
    top_n: int = Field(20, ge=1, description="Max pathways to display (sorted by p-value)")


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.get("/health", summary="Health check")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "chart-service"}


@app.post("/charts/pca", response_class=Response, summary="PCA score plot")
def charts_pca(req: PCARequest) -> Response:
    """Return a PNG PCA score plot with 95% confidence ellipses."""
    try:
        X = np.array(req.X, dtype=float)
        fig = plot_pca(X, req.groups, title=req.title)
        return Response(content=figure_to_bytes(fig), media_type=_PNG)
    except (ValueError, Exception) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/charts/volcano", response_class=Response, summary="Volcano plot")
def charts_volcano(req: VolcanoRequest) -> Response:
    """Return a PNG volcano plot coloured by significance."""
    try:
        fig = plot_volcano(
            log2fc=np.array(req.log2fc, dtype=float),
            pvalues=np.array(req.pvalues, dtype=float),
            names=req.names,
            fc_cutoff=req.fc_cutoff,
            p_cutoff=req.p_cutoff,
            top_n_labels=req.top_n_labels,
        )
        return Response(content=figure_to_bytes(fig), media_type=_PNG)
    except (ValueError, Exception) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/charts/heatmap", response_class=Response, summary="Clustered heatmap")
def charts_heatmap(req: HeatmapRequest) -> Response:
    """Return a PNG clustered heatmap with dendrograms."""
    try:
        X = np.array(req.X, dtype=float)
        fig = plot_heatmap(
            X=X,
            sample_labels=req.sample_labels,
            feature_labels=req.feature_labels,
            groups=req.groups,
            z_score=req.z_score,
        )
        return Response(content=figure_to_bytes(fig), media_type=_PNG)
    except (ValueError, Exception) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/charts/boxplot", response_class=Response, summary="Feature boxplot")
def charts_boxplot(req: BoxplotRequest) -> Response:
    """Return a PNG box + strip plot for a single feature."""
    try:
        fig = plot_feature_boxplot(
            intensities=np.array(req.intensities, dtype=float),
            groups=req.groups,
            feature_name=req.feature_name,
        )
        return Response(content=figure_to_bytes(fig), media_type=_PNG)
    except (ValueError, Exception) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/charts/pathway", response_class=Response, summary="Pathway enrichment bubble chart")
def charts_pathway(req: PathwayRequest) -> Response:
    """Return a PNG pathway enrichment bubble chart."""
    try:
        fig = plot_pathway_bubble(
            pathway_names=req.pathway_names,
            fold_enrichment=np.array(req.fold_enrichment, dtype=float),
            pvalues=np.array(req.pvalues, dtype=float),
            hit_counts=req.hit_counts,
            top_n=req.top_n,
        )
        return Response(content=figure_to_bytes(fig), media_type=_PNG)
    except (ValueError, Exception) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

"""Spectral library management API endpoints."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException

from app.engine.annot_adapter import AnnotWorkerAdapter
from app.engine.registry import engine_registry

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/libraries", tags=["libraries"])


def _get_annot_adapter() -> AnnotWorkerAdapter:
    adapter = engine_registry.get("annot")
    if adapter is None or not isinstance(adapter, AnnotWorkerAdapter):
        raise HTTPException(status_code=503, detail="annot-worker not registered")
    return adapter


@router.get("")
async def list_libraries() -> list[dict[str, Any]]:
    """List all registered spectral libraries with their tags."""
    adapter = _get_annot_adapter()
    try:
        return await adapter.get_registry()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"annot-worker unavailable: {e}")


@router.get("/tags")
async def list_tags() -> dict[str, list[str]]:
    """List all available tag dimensions and their values.

    Returns e.g. {"instrument": ["orbitrap", "qtof", ...], "organism": [...]}
    """
    adapter = _get_annot_adapter()
    try:
        return await adapter.get_tags()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"annot-worker unavailable: {e}")

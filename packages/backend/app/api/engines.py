"""Engine management API routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.engine.registry import engine_registry

router = APIRouter(prefix="/engines", tags=["engines"])


@router.get("")
async def list_engines() -> list[dict]:
    """List all registered engines."""
    return engine_registry.list_engines()


@router.get("/{engine_name}/params")
async def get_engine_params(engine_name: str) -> dict:
    """Get default params and JSON schema for an engine."""
    engine = engine_registry.get(engine_name)
    if engine is None:
        raise HTTPException(status_code=404, detail=f"Engine '{engine_name}' not found")

    return {
        "engine": engine_name,
        "version": engine.engine_version,
        "defaults": engine.get_default_params(),
        "schema": engine.get_param_schema(),
    }


@router.get("/{engine_name}/health")
async def check_engine_health(engine_name: str) -> dict:
    """Check if an engine container is healthy."""
    engine = engine_registry.get(engine_name)
    if engine is None:
        raise HTTPException(status_code=404, detail=f"Engine '{engine_name}' not found")

    healthy = await engine.health_check()
    return {"engine": engine_name, "healthy": healthy}


@router.get("/health")
async def check_all_health() -> dict:
    """Check health of all engine containers."""
    return await engine_registry.health_check_all()

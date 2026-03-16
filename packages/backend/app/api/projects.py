"""Project management API routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.models.project import ProjectCreate, ProjectResponse, ProjectUpdate
from app.services import project_service

router = APIRouter(prefix="/projects", tags=["projects"])


@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(payload: ProjectCreate) -> ProjectResponse:
    """Create a new project."""
    return project_service.create_project(
        name=payload.name,
        description=payload.description,
    )


@router.get("", response_model=list[ProjectResponse])
async def list_projects() -> list[ProjectResponse]:
    """List all projects."""
    return project_service.list_projects()


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: str) -> ProjectResponse:
    """Get a project by ID."""
    project = project_service.get_project(project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


@router.put("/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: str, payload: ProjectUpdate) -> ProjectResponse:
    """Update project name and/or description."""
    project = project_service.update_project(
        project_id,
        payload.model_dump(exclude_unset=False),
    )
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


@router.delete("/{project_id}", status_code=204)
async def delete_project(project_id: str) -> None:
    """Delete a project."""
    deleted = project_service.delete_project(project_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Project not found")


@router.post("/{project_id}/analyses/{analysis_id}", response_model=ProjectResponse)
async def add_analysis(project_id: str, analysis_id: str) -> ProjectResponse:
    """Add an analysis to a project."""
    project = project_service.add_analysis_to_project(project_id, analysis_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


@router.delete("/{project_id}/analyses/{analysis_id}", response_model=ProjectResponse)
async def remove_analysis(project_id: str, analysis_id: str) -> ProjectResponse:
    """Remove an analysis from a project."""
    project = project_service.remove_analysis_from_project(project_id, analysis_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return project

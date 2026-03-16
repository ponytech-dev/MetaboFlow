"""Pydantic models for format conversion."""

from __future__ import annotations

from pydantic import BaseModel


class FormatInfo(BaseModel):
    """Description of a supported format."""

    name: str
    extension: str
    description: str
    supports_import: bool
    supports_export: bool


class ConvertRequest(BaseModel):
    """Request model for format conversion."""

    source_format: str
    target_format: str

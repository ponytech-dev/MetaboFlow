"""Pydantic models for annot-worker API."""

from __future__ import annotations

from pydantic import BaseModel, Field


class TagFilter(BaseModel):
    """Multi-label filter for selecting spectral libraries."""

    instrument: list[str] = Field(default_factory=list)
    organism: list[str] = Field(default_factory=list)
    compound_class: list[str] = Field(default_factory=list)
    confidence: list[str] = Field(default_factory=lambda: ["high", "medium", "low"])


class MS2Spectrum(BaseModel):
    """A single MS2 spectrum for annotation."""

    feature_id: str
    precursor_mz: float
    precursor_type: str = "[M+H]+"
    mz_array: list[float]
    intensity_array: list[float]


class AnnotateRequest(BaseModel):
    """Request body for /annotate endpoint."""

    spectra: list[MS2Spectrum]
    tag_filter: TagFilter = Field(default_factory=TagFilter)
    polarity: str = "positive"
    ms2_tolerance_da: float = 0.02
    min_score: float = 0.7
    method: str = "CosineGreedy"  # CosineGreedy, ModifiedCosine, CosineHungarian
    max_matches: int = 1


class AnnotationHit(BaseModel):
    """A single annotation result."""

    feature_id: str
    compound_name: str
    inchikey: str = ""
    formula: str = ""
    adduct: str = ""
    score: float
    n_matched_peaks: int
    library_source: str
    data_type: str  # experimental / predicted
    msi_level: int  # 2 or 3


class AnnotateResponse(BaseModel):
    """Response body for /annotate endpoint."""

    hits: list[AnnotationHit]
    n_query_spectra: int
    n_matched: int
    n_reference_spectra: int
    libraries_used: list[str]


class LibraryInfo(BaseModel):
    """Info about a registered spectral library."""

    id: int
    file_path: str
    source: str
    data_type: str
    polarity: str
    spectra_count: int
    tags: dict[str, list[str]]

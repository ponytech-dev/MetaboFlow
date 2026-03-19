"""Pydantic models for sirius-worker API."""

from __future__ import annotations

from pydantic import BaseModel, Field


class MS2Spectrum(BaseModel):
    """A single MS2 spectrum for SIRIUS prediction."""

    feature_id: str
    precursor_mz: float
    precursor_type: str = "[M+H]+"
    ms1_mz_array: list[float] = Field(default_factory=list)
    ms1_intensity_array: list[float] = Field(default_factory=list)
    ms2_mz_array: list[float]
    ms2_intensity_array: list[float]


class PredictRequest(BaseModel):
    """Request body for /predict endpoint."""

    spectra: list[MS2Spectrum]
    database: str = "bio"  # bio, pubchem, kegg, hmdb
    max_candidates: int = 5
    instrument: str = "orbitrap"  # orbitrap, qtof, fticr


class FormulaCandidate(BaseModel):
    """A molecular formula candidate from SIRIUS."""

    molecular_formula: str
    adduct: str
    sirius_score: float
    isotope_score: float = 0.0
    tree_score: float = 0.0
    zodiac_score: float | None = None


class StructureCandidate(BaseModel):
    """A structure candidate from CSI:FingerID."""

    inchikey: str
    inchi: str = ""
    compound_name: str
    smiles: str = ""
    molecular_formula: str
    csi_score: float
    tanimoto_similarity: float = 0.0
    database_links: dict[str, str] = Field(default_factory=dict)


class PredictionResult(BaseModel):
    """Prediction result for a single feature."""

    feature_id: str
    precursor_mz: float
    top_formula: FormulaCandidate | None = None
    top_structure: StructureCandidate | None = None
    formula_candidates: list[FormulaCandidate] = Field(default_factory=list)
    structure_candidates: list[StructureCandidate] = Field(default_factory=list)
    compound_classes: list[str] = Field(default_factory=list)  # CANOPUS
    msi_level: int = 3  # SIRIUS + CSI:FingerID → Level 2.5 (treated as 3 strict MSI)


class PredictResponse(BaseModel):
    """Response body for /predict endpoint."""

    predictions: list[PredictionResult]
    n_input: int
    n_predicted: int
    sirius_version: str = ""

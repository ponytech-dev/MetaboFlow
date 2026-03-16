"""Pydantic models for analysis configuration and results."""

from __future__ import annotations

import enum
from datetime import datetime

from pydantic import BaseModel, Field


# ── Enums ────────────────────────────────────────────────────────────────────


class AnalysisStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class EngineType(str, enum.Enum):
    XCMS = "xcms"
    MZMINE = "mzmine"
    PYOPENMS = "pyopenms"
    MSDIAL = "msdial"


class SampleType(str, enum.Enum):
    SAMPLE = "sample"
    QC = "qc"
    BLANK = "blank"


class BatchCorrectionMethod(str, enum.Enum):
    SERRF = "serrf"
    COMBAT = "combat"
    QC_RLSC = "qc_rlsc"
    NONE = "none"


class StatAnalysisType(str, enum.Enum):
    PCA = "pca"
    PLSDA = "plsda"
    DIFFERENTIAL = "differential"


class PathwayWorkflow(str, enum.Enum):
    SMPDB = "smpdb"
    MSEA = "msea"
    KEGG_ORA = "kegg_ora"
    QEA = "qea"


class ExportFormat(str, enum.Enum):
    PDF = "pdf"
    SVG = "svg"
    PNG = "png"


# ── Request Models ───────────────────────────────────────────────────────────


class SampleMetadata(BaseModel):
    sample_id: str
    group: str
    batch: str = "batch1"
    sample_type: SampleType = SampleType.SAMPLE


class PeakDetectionParams(BaseModel):
    engine: EngineType = EngineType.XCMS
    ppm: float = 15.0
    peakwidth_min: float = 5.0
    peakwidth_max: float = 30.0
    snthresh: float = 5.0
    noise: float = 500.0
    min_fraction: float = 0.5
    multi_engine: bool = False


class QCParams(BaseModel):
    batch_correction: BatchCorrectionMethod = BatchCorrectionMethod.NONE


class StatParams(BaseModel):
    analysis_type: StatAnalysisType = StatAnalysisType.DIFFERENTIAL
    fc_cutoff: float = 1.5
    p_value_cutoff: float = 0.05
    fdr_method: str = "BH"


class AnnotationParams(BaseModel):
    databases: list[str] = Field(default_factory=lambda: ["hmdb", "mona", "massbank"])
    ms1_ppm: float = 15.0
    rt_tolerance: float = 30.0


class PathwayParams(BaseModel):
    workflows: list[PathwayWorkflow] = Field(default_factory=lambda: [PathwayWorkflow.KEGG_ORA])
    organism: str = "hsa"
    p_cutoff: float = 0.05


class ExportParams(BaseModel):
    chart_types: list[str] = Field(
        default_factory=lambda: ["volcano", "pca", "heatmap", "boxplot", "pathway_bubble"]
    )
    format: ExportFormat = ExportFormat.PDF


class AnalysisConfig(BaseModel):
    """Full analysis pipeline configuration."""

    sample_metadata: list[SampleMetadata]
    peak_detection: PeakDetectionParams = Field(default_factory=PeakDetectionParams)
    qc: QCParams = Field(default_factory=QCParams)
    statistics: StatParams = Field(default_factory=StatParams)
    annotation: AnnotationParams = Field(default_factory=AnnotationParams)
    pathway: PathwayParams = Field(default_factory=PathwayParams)
    export: ExportParams = Field(default_factory=ExportParams)


# ── Response Models ──────────────────────────────────────────────────────────


class AnalysisProgress(BaseModel):
    analysis_id: str
    status: AnalysisStatus
    current_step: int = 0
    total_steps: int = 7
    step_name: str = ""
    progress_pct: float = 0.0
    message: str = ""
    started_at: datetime | None = None
    completed_at: datetime | None = None


class AnalysisResult(BaseModel):
    analysis_id: str
    status: AnalysisStatus
    n_features: int = 0
    n_significant: int = 0
    n_annotated: int = 0
    n_pathways: int = 0
    result_files: list[str] = Field(default_factory=list)
    metabodata_path: str | None = None

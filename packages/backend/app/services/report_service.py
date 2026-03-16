"""Report generation service.

Produces HTML reports from MetaboFlow analysis results, including an
auto-generated Methods section derived from MetaboData provenance chains.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, select_autoescape


# Jinja2 environment — templates live alongside this package under app/templates/
_TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
_jinja_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=select_autoescape(["html"]),
)

# Human-readable step descriptions for the Methods paragraph
_STEP_DESCRIPTIONS: dict[str, str] = {
    "peak_detection": "Peak detection",
    "peak_grouping": "Peak grouping and alignment",
    "gap_filling": "Gap filling",
    "normalization": "Data normalization",
    "batch_correction": "Batch effect correction",
    "qc_filtering": "QC-based feature filtering",
    "statistical_analysis": "Statistical analysis",
    "annotation": "Feature annotation",
    "pathway_enrichment": "Pathway enrichment analysis",
    "export": "Data export",
}

# Verbose engine names for Methods prose
_ENGINE_NAMES: dict[str, str] = {
    "xcms": "XCMS3",
    "mzmine": "MZmine 3",
    "pyopenms": "pyOpenMS",
    "msdial": "MS-DIAL",
    "serrf": "SERRF",
    "combat": "ComBat",
    "qc_rlsc": "QC-RLSC",
    "metaboanalyst": "MetaboAnalystR",
}


# ── Public API ────────────────────────────────────────────────────────────────


def generate_report(analysis_id: str, include_charts: bool = True) -> str:
    """Render a full HTML report for *analysis_id*.

    Args:
        analysis_id: The 8-character analysis identifier.
        include_charts: When True, volcano plot and QC chart placeholders are
            included in the rendered output.

    Returns:
        Complete HTML document as a string.

    Raises:
        KeyError: If *analysis_id* does not exist.
    """
    data = _get_analysis_data(analysis_id)
    config = data["config"]

    # Build template context
    provenance = _extract_provenance(data)
    ctx: dict[str, Any] = {
        "analysis_id": analysis_id,
        "generated_at": datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC"),
        "status": data["status"].value if hasattr(data["status"], "value") else str(data["status"]),
        # Section 1 — configuration
        "engine": config.peak_detection.engine.value,
        "params_table": _format_params_table(_peak_params_dict(config)),
        # Section 2 — sample summary
        "n_samples": len(config.sample_metadata),
        "n_groups": len({s.group for s in config.sample_metadata}),
        "groups": sorted({s.group for s in config.sample_metadata}),
        "batches": sorted({s.batch for s in config.sample_metadata}),
        "n_qc": sum(1 for s in config.sample_metadata if s.sample_type.value == "qc"),
        # Section 3 — results overview
        "n_features": data.get("n_features", 0),
        "n_significant": data.get("n_significant", 0),
        "n_annotated": data.get("n_annotated", 0),
        "n_pathways": data.get("n_pathways", 0),
        "results_summary": _format_results_summary(data),
        "include_charts": include_charts,
        # Section 4 — methods
        "methods_paragraph": generate_methods_paragraph(provenance),
        # Section 5 — provenance
        "provenance": provenance,
    }

    template = _jinja_env.get_template("report.html")
    return template.render(**ctx)


def generate_methods_paragraph(provenance: dict[str, Any]) -> str:
    """Auto-generate a Methods section paragraph from a provenance chain dict.

    The provenance dict is expected to follow the MetaboData.uns["provenance"]
    schema::

        {
            "created_at": "<ISO datetime>",
            "steps": [
                {
                    "step": "peak_detection",
                    "engine": "xcms",
                    "engine_version": "3.22.0",
                    "params": {"ppm": 15, ...},
                    "timestamp": "<ISO datetime>",
                },
                ...
            ]
        }

    Returns an empty string when *provenance* contains no steps.
    """
    steps: list[dict[str, Any]] = provenance.get("steps", [])
    if not steps:
        return ""

    sentences: list[str] = []
    for step_info in steps:
        step_key = step_info.get("step", "")
        engine_raw = step_info.get("engine", "")
        engine_ver = step_info.get("engine_version", "")
        params = step_info.get("params", {})

        step_label = _STEP_DESCRIPTIONS.get(step_key, step_key.replace("_", " ").capitalize())
        engine_label = _ENGINE_NAMES.get(engine_raw.lower(), engine_raw)
        version_str = f" (v{engine_ver})" if engine_ver else ""

        param_parts = _humanize_params(params)
        param_str = f" with {param_parts}" if param_parts else ""

        sentences.append(f"{step_label} was performed using {engine_label}{version_str}{param_str}.")

    return " ".join(sentences)


def _format_params_table(params: dict[str, Any]) -> str:
    """Render *params* as an HTML ``<table>`` string."""
    if not params:
        return "<p><em>No parameters recorded.</em></p>"

    rows = []
    for key, value in params.items():
        display_key = key.replace("_", " ").title()
        rows.append(f"<tr><td>{display_key}</td><td>{_format_value(value)}</td></tr>")

    return (
        "<table class='params-table'>"
        "<thead><tr><th>Parameter</th><th>Value</th></tr></thead>"
        "<tbody>" + "".join(rows) + "</tbody>"
        "</table>"
    )


def _format_results_summary(data: dict[str, Any]) -> str:
    """Render key result counters as a compact HTML summary block."""
    n_features = data.get("n_features", 0)
    n_significant = data.get("n_significant", 0)
    n_annotated = data.get("n_annotated", 0)
    n_pathways = data.get("n_pathways", 0)

    status = data.get("status")
    status_val = status.value if hasattr(status, "value") else str(status)
    if status_val not in ("completed",):
        return f"<p class='muted'>Analysis is {status_val}. Results not yet available.</p>"

    pct_sig = f"{n_significant / n_features * 100:.1f}%" if n_features else "N/A"
    pct_ann = f"{n_annotated / n_features * 100:.1f}%" if n_features else "N/A"

    return (
        "<ul class='results-summary'>"
        f"<li><strong>Total features detected:</strong> {n_features:,}</li>"
        f"<li><strong>Significant features (DA):</strong> {n_significant:,} ({pct_sig})</li>"
        f"<li><strong>Annotated features:</strong> {n_annotated:,} ({pct_ann})</li>"
        f"<li><strong>Enriched pathways:</strong> {n_pathways:,}</li>"
        "</ul>"
    )


# ── Internal helpers ──────────────────────────────────────────────────────────


def _get_analysis_data(analysis_id: str) -> dict[str, Any]:
    """Build a unified data dict from the repository layer."""
    from app.db.base import SessionLocal
    from app.db.repository import AnalysisRepository
    from app.models.analysis import AnalysisConfig, AnalysisStatus

    session = SessionLocal()
    try:
        repo = AnalysisRepository(session)
        row = repo.get_by_id(analysis_id)
        if row is None:
            raise KeyError(f"Analysis '{analysis_id}' not found")

        config_raw = repo.get_config_dict(analysis_id)
        progress = repo.get_progress_dict(analysis_id) or {}
        result = repo.get_result_dict(analysis_id) or {}
    finally:
        session.close()

    # Re-hydrate config as AnalysisConfig (report template needs attribute access)
    try:
        config_obj = AnalysisConfig.model_validate(config_raw)
    except Exception:
        config_obj = None  # type: ignore[assignment]

    status_str = row.status
    try:
        status_obj = AnalysisStatus(status_str)
    except ValueError:
        status_obj = AnalysisStatus.PENDING  # type: ignore[assignment]

    return {
        "id": row.id,
        "config": config_obj,
        "status": status_obj,
        "current_step": progress.get("current_step", 0),
        "step_name": progress.get("step_name", ""),
        "progress_pct": progress.get("progress_pct", 0.0),
        "message": progress.get("message", ""),
        "started_at": _parse_dt_str(progress.get("started_at")),
        "completed_at": _parse_dt_str(progress.get("completed_at")),
        "n_features": result.get("n_features", 0),
        "n_significant": result.get("n_significant", 0),
        "n_annotated": result.get("n_annotated", 0),
        "n_pathways": result.get("n_pathways", 0),
        "result_files": result.get("result_files", []),
    }


def _extract_provenance(data: dict[str, Any]) -> dict[str, Any]:
    """Extract provenance from stored MetaboData or build a synthetic one from config."""
    # In a real run the MetaboData object would be persisted; for now we
    # synthesise a provenance dict from the stored AnalysisConfig so tests
    # and the pending/running states still produce meaningful output.
    config = data["config"]
    pd_params = _peak_params_dict(config)

    steps: list[dict[str, Any]] = [
        {
            "step": "peak_detection",
            "engine": config.peak_detection.engine.value,
            "engine_version": "",
            "params": pd_params,
            "timestamp": (data.get("started_at") or datetime.now(UTC)).isoformat()
            if not isinstance(data.get("started_at"), str)
            else data["started_at"],
        }
    ]

    bc = config.qc.batch_correction.value
    if bc != "none":
        steps.append(
            {
                "step": "batch_correction",
                "engine": bc,
                "engine_version": "",
                "params": {"method": bc},
                "timestamp": (data.get("started_at") or datetime.now(UTC)).isoformat()
                if not isinstance(data.get("started_at"), str)
                else data["started_at"],
            }
        )

    steps.append(
        {
            "step": "statistical_analysis",
            "engine": "metaboanalyst",
            "engine_version": "",
            "params": {
                "analysis_type": config.statistics.analysis_type.value,
                "fc_cutoff": config.statistics.fc_cutoff,
                "p_value_cutoff": config.statistics.p_value_cutoff,
                "fdr_method": config.statistics.fdr_method,
            },
            "timestamp": (data.get("completed_at") or datetime.now(UTC)).isoformat()
            if not isinstance(data.get("completed_at"), str)
            else data["completed_at"],
        }
    )

    return {
        "created_at": (data.get("started_at") or datetime.now(UTC)).isoformat()
        if not isinstance(data.get("started_at"), str)
        else data["started_at"],
        "steps": steps,
    }


def _peak_params_dict(config: Any) -> dict[str, Any]:
    pd = config.peak_detection
    return {
        "ppm": pd.ppm,
        "peakwidth_min": pd.peakwidth_min,
        "peakwidth_max": pd.peakwidth_max,
        "snthresh": pd.snthresh,
        "noise": pd.noise,
        "min_fraction": pd.min_fraction,
    }


def _humanize_params(params: dict[str, Any]) -> str:
    """Convert a params dict to a compact human-readable string."""
    if not params:
        return ""
    parts = []
    for k, v in list(params.items())[:4]:  # cap at 4 key params for readability
        label = k.replace("_", " ")
        parts.append(f"{label} = {_format_value(v)}")
    suffix = f", and {len(params) - 4} additional parameters" if len(params) > 4 else ""
    return ", ".join(parts) + suffix


def _format_value(value: Any) -> str:
    if isinstance(value, float):
        return f"{value:g}"
    if isinstance(value, list):
        return "[" + ", ".join(_format_value(v) for v in value) + "]"
    return str(value)


def _parse_dt_str(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None

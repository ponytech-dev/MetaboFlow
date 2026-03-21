"""Celery tasks for running analysis pipeline steps."""

from __future__ import annotations

import asyncio
import logging

from app.engine.registry import engine_registry
from app.models.analysis import AnalysisStatus
from app.services import analysis_service
from app.services.annotation_orchestrator import run_layered_annotation
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

STEP_NAMES = [
    "数据导入 / Data Import",
    "峰检测 / Peak Detection",
    "质量控制 / Quality Control",
    "统计分析 / Statistical Analysis",
    "代谢物注释 / Annotation",
    "通路分析 / Pathway Analysis",
    "图表导出 / Export",
]


@celery_app.task(bind=True, name="run_analysis_pipeline")
def run_analysis_pipeline(self, analysis_id: str, config_dict: dict) -> dict:
    """Run the full analysis pipeline.

    Each step updates progress via the analysis_service.
    """
    from app.models.analysis import AnalysisConfig

    progress = analysis_service.get_progress(analysis_id)
    if progress is None:
        return {"error": f"Analysis {analysis_id} not found"}

    config = AnalysisConfig(**config_dict)
    upload_dir = analysis_service.get_upload_dir(analysis_id)
    results_dir = str(Path(upload_dir).parent.parent / "results" / analysis_id) if upload_dir else f"/data/results/{analysis_id}"

    from pathlib import Path
    Path(results_dir).mkdir(parents=True, exist_ok=True)

    analysis_service.update_progress(analysis_id, status=AnalysisStatus.RUNNING)

    # Runtime state (not persisted, just for passing data between steps)
    runtime = {}

    try:
        for step_idx, step_name in enumerate(STEP_NAMES):
            analysis_service.update_progress(
                analysis_id,
                current_step=step_idx + 1,
                step_name=step_name,
                progress_pct=(step_idx / len(STEP_NAMES)) * 100,
                message=f"Running: {step_name}",
            )

            if step_idx == 1:  # Peak Detection
                _run_peak_detection(analysis_id, config, upload_dir, results_dir, runtime)
            elif step_idx == 3:  # Statistical Analysis
                _run_statistics(analysis_id, config, results_dir, runtime)
            elif step_idx == 4:  # Annotation
                _run_annotation(analysis_id, config, results_dir, runtime)

        analysis_service.update_progress(
            analysis_id,
            status=AnalysisStatus.COMPLETED,
            current_step=7,
            progress_pct=100.0,
            message="Analysis completed successfully",
        )

        return {"analysis_id": analysis_id, "status": "completed"}

    except Exception as e:
        logger.exception("Analysis %s failed", analysis_id)
        analysis_service.update_progress(
            analysis_id,
            status=AnalysisStatus.FAILED,
            message=f"Error: {e!s}",
        )
        return {"analysis_id": analysis_id, "status": "failed", "error": str(e)}


def _run_peak_detection(analysis_id: str, config, upload_dir: str, results_dir: str, runtime: dict) -> None:
    """Execute peak detection via xcms /run_pipeline → MetaboData HDF5."""
    xcms = engine_registry.get("xcms")
    if xcms is None:
        logger.warning("XCMS adapter not available, skipping peak detection")
        return

    result = asyncio.get_event_loop().run_until_complete(
        xcms.run_pipeline(
            mzml_dir=upload_dir,
            output_dir=results_dir,
            polarity=getattr(config.peak_detection, 'polarity', 'positive'),
            deconv_method=getattr(config.peak_detection, 'deconv_method', 'camera'),
        )
    )

    runtime["metabodata_path"] = result.get("metabodata_path", f"{results_dir}/metabodata.h5")
    runtime["n_features"] = result.get("n_features", 0)
    logger.info("Peak detection for %s: %d features", analysis_id, runtime["n_features"])


def _run_statistics(analysis_id: str, config, results_dir: str, runtime: dict) -> None:
    """Execute statistical analysis via stats /run_stats on MetaboData HDF5."""
    stats = engine_registry.get("stats")
    if stats is None:
        logger.warning("Stats adapter not available, skipping statistics")
        return

    metabodata_path = runtime.get("metabodata_path", f"{results_dir}/metabodata.h5")

    result = asyncio.get_event_loop().run_until_complete(
        stats.run_stats(
            metabodata_path=metabodata_path,
            output_dir=results_dir,
            alpha=config.statistics.p_value_cutoff,
            fc_cut=config.statistics.fc_cutoff,
        )
    )

    runtime["metabodata_path"] = result.get("metabodata_path", metabodata_path)
    runtime["n_significant"] = result.get("n_significant", 0)
    logger.info("Statistics for %s: %d significant", analysis_id, runtime["n_significant"])


def _run_annotation(analysis_id: str, config, results_dir: str, runtime: dict) -> None:
    """Execute metabolite annotation (placeholder — full implementation in Phase 1)."""
    logger.info("Annotation for %s: using MetaboData at %s", analysis_id, runtime.get("metabodata_path", "N/A"))
    # TODO: read features from MetaboData HDF5, run annot-worker MS2 matching
    # For now, annotation is done within the E2E R script (run_e2e_qexactive.R)
    # Full Python-side annotation will be wired in Phase 1 iteration 2

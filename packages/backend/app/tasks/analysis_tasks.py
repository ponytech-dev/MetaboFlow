"""Celery tasks for running analysis pipeline steps."""

from __future__ import annotations

import asyncio
import logging

from app.engine.registry import engine_registry
from app.models.analysis import AnalysisStatus
from app.services.analysis_service import _analyses, update_progress
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
def run_analysis_pipeline(self, analysis_id: str) -> dict:
    """Run the full analysis pipeline.

    Each step updates progress via the analysis_service.
    """
    data = _analyses.get(analysis_id)
    if data is None:
        return {"error": f"Analysis {analysis_id} not found"}

    config = data["config"]
    results_dir = data["results_dir"]
    upload_dir = data["upload_dir"]

    update_progress(analysis_id, status=AnalysisStatus.RUNNING)

    try:
        for step_idx, step_name in enumerate(STEP_NAMES):
            update_progress(
                analysis_id,
                current_step=step_idx + 1,
                step_name=step_name,
                progress_pct=(step_idx / len(STEP_NAMES)) * 100,
                message=f"Running: {step_name}",
            )

            if step_idx == 1:  # Peak Detection
                _run_peak_detection(analysis_id, config, upload_dir, results_dir)
            elif step_idx == 3:  # Statistical Analysis
                _run_statistics(analysis_id, config, results_dir)
            # Other steps: placeholder for now

        update_progress(
            analysis_id,
            status=AnalysisStatus.COMPLETED,
            current_step=7,
            progress_pct=100.0,
            message="Analysis completed successfully",
        )

        return {"analysis_id": analysis_id, "status": "completed"}

    except Exception as e:
        logger.exception("Analysis %s failed", analysis_id)
        update_progress(
            analysis_id,
            status=AnalysisStatus.FAILED,
            message=f"Error: {e!s}",
        )
        return {"analysis_id": analysis_id, "status": "failed", "error": str(e)}


def _run_peak_detection(analysis_id: str, config, upload_dir: str, results_dir: str) -> None:
    """Execute peak detection step."""
    xcms = engine_registry.get("xcms")
    if xcms is None:
        logger.warning("XCMS adapter not available, skipping peak detection")
        return

    params = {
        "ppm": config.peak_detection.ppm,
        "peakwidth": [config.peak_detection.peakwidth_min, config.peak_detection.peakwidth_max],
        "snthresh": config.peak_detection.snthresh,
        "noise": config.peak_detection.noise,
        "min_fraction": config.peak_detection.min_fraction,
        "polarity": "positive",
    }

    validation = xcms.validate_params(params)
    if not validation.is_valid:
        raise ValueError(f"Invalid XCMS params: {validation.errors}")

    # Run async adapter in sync context (Celery worker)
    result = asyncio.get_event_loop().run_until_complete(xcms.run(upload_dir, params, results_dir))

    data = _analyses.get(analysis_id)
    if data and "n_features" in result:
        data["n_features"] = result["n_features"]


def _run_statistics(analysis_id: str, config, results_dir: str) -> None:
    """Execute statistical analysis step."""
    stats = engine_registry.get("stats")
    if stats is None:
        logger.warning("Stats adapter not available, skipping statistics")
        return

    params = {
        "analysis_type": config.statistics.analysis_type.value,
        "fc_cutoff": config.statistics.fc_cutoff,
        "p_value_cutoff": config.statistics.p_value_cutoff,
        "fdr_method": config.statistics.fdr_method,
    }

    metabodata_path = f"{results_dir}/processed.metabodata"
    result = asyncio.get_event_loop().run_until_complete(stats.run(metabodata_path, params, results_dir))

    data = _analyses.get(analysis_id)
    if data and "n_significant" in result:
        data["n_significant"] = result["n_significant"]

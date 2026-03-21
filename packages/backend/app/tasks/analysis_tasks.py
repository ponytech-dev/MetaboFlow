"""Celery tasks for running analysis pipeline steps."""

from __future__ import annotations

import asyncio
import logging

from app.engine.registry import engine_registry
from app.models.analysis import AnalysisStatus
from app.services.analysis_service import _analyses, update_progress
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
            elif step_idx == 4:  # Annotation
                _run_annotation(analysis_id, config, results_dir)

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
    """Execute peak detection via xcms /run_pipeline → MetaboData HDF5."""
    xcms = engine_registry.get("xcms")
    if xcms is None:
        logger.warning("XCMS adapter not available, skipping peak detection")
        return

    # Use new /run_pipeline endpoint that outputs MetaboData HDF5
    result = asyncio.get_event_loop().run_until_complete(
        xcms.run_pipeline(
            mzml_dir=upload_dir,
            output_dir=results_dir,
            polarity=getattr(config.peak_detection, 'polarity', 'positive'),
            deconv_method=getattr(config.peak_detection, 'deconv_method', 'camera'),
        )
    )

    data = _analyses.get(analysis_id)
    if data:
        data["metabodata_path"] = result.get("metabodata_path", f"{results_dir}/metabodata.h5")
        data["n_features"] = result.get("n_features", 0)


def _run_statistics(analysis_id: str, config, results_dir: str) -> None:
    """Execute statistical analysis via stats /run_stats on MetaboData HDF5."""
    stats = engine_registry.get("stats")
    if stats is None:
        logger.warning("Stats adapter not available, skipping statistics")
        return

    data = _analyses.get(analysis_id)
    metabodata_path = data.get("metabodata_path", f"{results_dir}/metabodata.h5") if data else f"{results_dir}/metabodata.h5"

    result = asyncio.get_event_loop().run_until_complete(
        stats.run_stats(
            metabodata_path=metabodata_path,
            output_dir=results_dir,
            alpha=config.statistics.p_value_cutoff,
            fc_cut=config.statistics.fc_cutoff,
        )
    )

    if data:
        data["metabodata_path"] = result.get("metabodata_path", metabodata_path)
        data["n_significant"] = result.get("n_significant", 0)


def _run_annotation(analysis_id: str, config, results_dir: str) -> None:
    """Execute metabolite annotation step (Level 2 + Level 3 + Level 4)."""
    data = _analyses.get(analysis_id)
    if data is None:
        return

    # Build feature list from previous steps (would come from MetaboData in production)
    features = data.get("features", [])
    ms2_spectra = data.get("ms2_spectra")  # None if no MS2 data

    annotation_params = config.annotation

    result = asyncio.get_event_loop().run_until_complete(
        run_layered_annotation(
            features=features,
            ms2_spectra=ms2_spectra,
            params=annotation_params,
            polarity="positive",
        )
    )

    summary = result.get("summary", {})
    if data is not None:
        data["n_annotated"] = summary.get("n_level2", 0) + summary.get("n_level3", 0)
        data["annotation_result"] = result

    logger.info(
        "Annotation for %s: L2=%d, L3=%d, L4=%d",
        analysis_id,
        summary.get("n_level2", 0),
        summary.get("n_level3", 0),
        summary.get("n_level4", 0),
    )

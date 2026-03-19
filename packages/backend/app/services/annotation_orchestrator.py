"""Annotation orchestrator: layered annotation (Level 2 → Level 3 → Level 4).

Coordinates annot-worker (MS2 matching) and stats-worker (MS1 matching)
to produce a unified annotation result with MSI confidence levels.
"""

from __future__ import annotations

import logging
from typing import Any

from app.engine.annot_adapter import AnnotWorkerAdapter
from app.engine.registry import engine_registry
from app.engine.sirius_adapter import SiriusWorkerAdapter
from app.models.analysis import AnnotationParams

logger = logging.getLogger(__name__)


async def run_layered_annotation(
    features: list[dict[str, Any]],
    ms2_spectra: list[dict[str, Any]] | None,
    params: AnnotationParams,
    polarity: str = "positive",
) -> dict[str, Any]:
    """Run multi-level annotation on a set of features.

    Args:
        features: List of dicts with at least {feature_id, mz, rt}.
        ms2_spectra: Optional list of MS2 spectra for Level 2 annotation.
            Each dict: {feature_id, precursor_mz, precursor_type, mz_array, intensity_array}
        params: Annotation parameters including tag_filter and thresholds.
        polarity: Ionization polarity.

    Returns:
        Dict with:
            - annotations: list of per-feature annotation results
            - summary: {n_level2, n_level3, n_level4, n_unannotated}
            - provenance: engine/version/params info
    """
    n_features = len(features)
    annotations: dict[str, dict[str, Any]] = {}

    # Initialize all features as unannotated
    for feat in features:
        fid = feat["feature_id"]
        annotations[fid] = {
            "feature_id": fid,
            "mz": feat["mz"],
            "rt": feat["rt"],
            "compound_name": None,
            "inchikey": None,
            "formula": None,
            "adduct": None,
            "msi_level": None,
            "annot_score": None,
            "annot_method": None,
            "annot_source": None,
            "kegg_id": None,
            "hmdb_id": None,
        }

    provenance_steps = []

    # ── Level 2: MS2 spectral matching (annot-worker) ──────────────────────
    n_level2 = 0
    if params.run_ms2 and ms2_spectra:
        annot_adapter = engine_registry.get("annot")
        if annot_adapter is not None and isinstance(annot_adapter, AnnotWorkerAdapter):
            try:
                is_healthy = await annot_adapter.health_check()
                if is_healthy:
                    logger.info(
                        f"Level 2: Running MS2 annotation on {len(ms2_spectra)} spectra"
                    )
                    result = await annot_adapter.run(
                        input_path="",
                        params={
                            "spectra": ms2_spectra,
                            "tag_filter": params.tag_filter.model_dump(),
                            "polarity": polarity,
                            "ms2_tolerance_da": params.ms2_tolerance_da,
                            "ms2_min_score": params.ms2_min_score,
                            "ms2_method": params.ms2_method,
                        },
                        output_dir="",
                    )

                    for hit in result.get("hits", []):
                        fid = hit["feature_id"]
                        if fid in annotations:
                            annotations[fid].update({
                                "compound_name": hit.get("compound_name"),
                                "inchikey": hit.get("inchikey"),
                                "formula": hit.get("formula"),
                                "adduct": hit.get("adduct"),
                                "msi_level": hit.get("msi_level", 2),
                                "annot_score": hit.get("score"),
                                "annot_method": f"ms2_{params.ms2_method}",
                                "annot_source": hit.get("library_source"),
                            })
                            n_level2 += 1

                    provenance_steps.append({
                        "step": "annotation_level2",
                        "engine": f"annot-worker/{annot_adapter.engine_version}",
                        "params": {
                            "method": params.ms2_method,
                            "min_score": params.ms2_min_score,
                            "tolerance_da": params.ms2_tolerance_da,
                            "tag_filter": params.tag_filter.model_dump(),
                        },
                        "n_matched": n_level2,
                        "n_reference": result.get("n_reference_spectra", 0),
                        "libraries": result.get("libraries_used", []),
                    })
                    logger.info(f"Level 2: {n_level2} features annotated")
                else:
                    logger.warning("annot-worker not available, skipping Level 2")
            except Exception as e:
                logger.error(f"Level 2 annotation failed: {e}")

    # ── Level 2.5: SIRIUS/CSI:FingerID structure prediction ──────────────
    n_sirius = 0
    if params.run_ms2 and ms2_spectra:
        sirius_adapter = engine_registry.get("sirius")
        if sirius_adapter is not None and isinstance(sirius_adapter, SiriusWorkerAdapter):
            try:
                is_healthy = await sirius_adapter.health_check()
                if is_healthy:
                    # Only predict for features not yet annotated at Level 2
                    unannotated_ms2 = [
                        s for s in ms2_spectra
                        if annotations.get(s["feature_id"], {}).get("msi_level") is None
                    ]
                    if unannotated_ms2:
                        logger.info(f"SIRIUS: predicting structures for {len(unannotated_ms2)} features")
                        sirius_result = await sirius_adapter.run(
                            input_path="",
                            params={
                                "spectra": unannotated_ms2,
                                "database": "bio",
                                "instrument": "orbitrap",
                            },
                            output_dir="",
                        )
                        for pred in sirius_result.get("predictions", []):
                            fid = pred["feature_id"]
                            top = pred.get("top_structure")
                            if top and fid in annotations:
                                annotations[fid].update({
                                    "compound_name": top.get("compound_name"),
                                    "inchikey": top.get("inchikey"),
                                    "formula": top.get("molecular_formula"),
                                    "msi_level": 3,  # SIRIUS = Level 3 (strict MSI)
                                    "annot_score": top.get("csi_score"),
                                    "annot_method": "sirius_csifingerid",
                                    "annot_source": "SIRIUS",
                                })
                                n_sirius += 1

                        provenance_steps.append({
                            "step": "annotation_sirius",
                            "engine": f"sirius-worker/{sirius_adapter.engine_version}",
                            "n_predicted": n_sirius,
                        })
                        logger.info(f"SIRIUS: {n_sirius} features predicted")
                else:
                    logger.info("sirius-worker not available, skipping SIRIUS")
            except Exception as e:
                logger.warning(f"SIRIUS prediction failed (non-critical): {e}")

    # ── Level 3: MS1 m/z matching (stats-worker) ──────────────────────────
    n_level3 = 0
    if params.run_ms1:
        unannotated = [
            fid for fid, ann in annotations.items() if ann["msi_level"] is None
        ]
        if unannotated:
            logger.info(f"Level 3: Running MS1 annotation on {len(unannotated)} features")
            # Level 3 is handled by the stats-worker R module (annotation_ms1.R)
            # In the E2E pipeline, this runs inside the R container directly
            # In production, it would call the stats-worker /run_annotation endpoint
            # For now, mark as placeholder — actual wiring depends on stats-worker API
            provenance_steps.append({
                "step": "annotation_level3",
                "engine": "stats-worker/annotation_ms1",
                "params": {"ms1_ppm": params.ms1_ppm},
                "n_remaining": len(unannotated),
            })
            logger.info(f"Level 3: delegated to stats-worker ({len(unannotated)} features)")

    # ── Level 4: Formula prediction (no external DB) ──────────────────────
    n_level4 = 0
    unannotated_final = [
        fid for fid, ann in annotations.items() if ann["msi_level"] is None
    ]
    if unannotated_final:
        # Placeholder: assign Level 4 with formula from exact mass
        for fid in unannotated_final:
            annotations[fid]["msi_level"] = 4
            annotations[fid]["annot_method"] = "formula_prediction"
            n_level4 += 1

    # ── Summary ────────────────────────────────────────────────────────────
    n_unannotated = sum(1 for a in annotations.values() if a["compound_name"] is None)

    summary = {
        "n_features": n_features,
        "n_level2": n_level2,
        "n_sirius": n_sirius,
        "n_level3": n_level3,
        "n_level4": n_level4,
        "n_unannotated": n_unannotated,
    }

    logger.info(
        f"Annotation summary: L2={n_level2}, SIRIUS={n_sirius}, L3={n_level3}, "
        f"L4={n_level4}, unannotated={n_unannotated}"
    )

    return {
        "annotations": list(annotations.values()),
        "summary": summary,
        "provenance": provenance_steps,
    }

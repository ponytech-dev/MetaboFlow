"""Core MS2 spectral matching engine using matchms."""

from __future__ import annotations

import logging
import os
from functools import lru_cache
from typing import Any

import numpy as np
from matchms import Spectrum
from matchms.importing import load_from_msp
from matchms.filtering import (
    default_filters,
    normalize_intensities,
    select_by_intensity,
    select_by_mz,
)
from matchms.similarity import CosineGreedy, CosineHungarian, ModifiedCosineGreedy

from app.config import settings
from app.models import AnnotateRequest, AnnotationHit, MS2Spectrum

logger = logging.getLogger(__name__)

SIMILARITY_FUNCTIONS = {
    "CosineGreedy": CosineGreedy,
    "ModifiedCosine": ModifiedCosineGreedy,
    "ModifiedCosineGreedy": ModifiedCosineGreedy,
    "CosineHungarian": CosineHungarian,
}


def _apply_filters(spectrum: Spectrum) -> Spectrum | None:
    """Apply standard matchms filters to a spectrum."""
    s = default_filters(spectrum)
    if s is None:
        return None
    s = normalize_intensities(s)
    if s is None:
        return None
    s = select_by_intensity(s, intensity_from=0.01)
    if s is None:
        return None
    s = select_by_mz(s, mz_from=10.0, mz_to=2000.0)
    return s


@lru_cache(maxsize=20)
def _load_library(file_path: str) -> list[Spectrum]:
    """Load and filter spectra from a single MSP file. Cached in memory."""
    full_path = os.path.join(settings.library_dir, file_path)
    if not os.path.exists(full_path):
        logger.warning(f"Library file not found: {full_path}")
        return []

    logger.info(f"Loading library: {file_path}")
    spectra = []
    for s in load_from_msp(full_path):
        filtered = _apply_filters(s)
        if filtered is not None and filtered.peaks.mz.size > 0:
            spectra.append(filtered)

    logger.info(f"  Loaded {len(spectra)} spectra from {file_path}")
    return spectra


def load_libraries(file_paths: list[str]) -> list[Spectrum]:
    """Load and merge spectra from multiple library files."""
    all_spectra = []
    for fp in file_paths:
        all_spectra.extend(_load_library(fp))
    return all_spectra


def _query_to_matchms(query: MS2Spectrum) -> Spectrum | None:
    """Convert API query spectrum to matchms Spectrum object."""
    if not query.mz_array or not query.intensity_array:
        return None

    mz = np.array(query.mz_array, dtype=float)
    intensities = np.array(query.intensity_array, dtype=float)

    if len(mz) == 0:
        return None

    metadata: dict[str, Any] = {
        "precursor_mz": query.precursor_mz,
        "adduct": query.precursor_type,
    }

    s = Spectrum(mz=mz, intensities=intensities, metadata=metadata)
    return _apply_filters(s)


def _get_data_type(ref_spectrum: Spectrum) -> str:
    """Determine if a reference spectrum is experimental or predicted."""
    # Check metadata hints
    meta = ref_spectrum.metadata
    for key in ["data_type", "library_quality", "Library_quality"]:
        val = str(meta.get(key, "")).lower()
        if "predict" in val or "in-silico" in val or "in silico" in val:
            return "predicted"
    return "experimental"


def _assign_msi_level(score: float, data_type: str) -> int:
    """Assign MSI confidence level based on score and data type."""
    if data_type == "experimental" and score >= 0.7:
        return 2
    return 3


def annotate(
    request: AnnotateRequest,
    reference_spectra: list[Spectrum],
    library_sources: list[str],
) -> list[AnnotationHit]:
    """Run MS2 spectral matching against reference spectra.

    Args:
        request: The annotation request with query spectra and parameters.
        reference_spectra: Pre-loaded reference spectra from selected libraries.
        library_sources: List of library source names (for provenance).

    Returns:
        List of annotation hits above the minimum score threshold.
    """
    if not reference_spectra:
        return []

    # Build similarity function
    sim_class = SIMILARITY_FUNCTIONS.get(request.method, CosineGreedy)
    similarity_function = sim_class(tolerance=request.ms2_tolerance_da)

    hits = []
    source_str = ",".join(set(library_sources))

    for query_spec in request.spectra:
        query_ms = _query_to_matchms(query_spec)
        if query_ms is None:
            continue

        best_score = 0.0
        best_ref = None
        best_n_matched = 0

        for ref in reference_spectra:
            # Quick precursor m/z pre-filter (±2 Da)
            ref_mz = ref.get("precursor_mz")
            if ref_mz is not None:
                if abs(ref_mz - query_spec.precursor_mz) > 2.0:
                    continue

            try:
                result = similarity_function.pair(query_ms, ref)
                # matchms 0.32 returns 0-d numpy array containing a tuple (score, n_matched)
                item = result.item() if hasattr(result, 'item') else result
                if isinstance(item, tuple):
                    score, n_matched = float(item[0]), int(item[1])
                else:
                    score, n_matched = float(item), 0
            except Exception:
                continue

            if score > best_score:
                best_score = score
                best_ref = ref
                best_n_matched = n_matched

        if best_ref is not None and best_score >= request.min_score:
            data_type = _get_data_type(best_ref)
            meta = best_ref.metadata

            hits.append(AnnotationHit(
                feature_id=query_spec.feature_id,
                compound_name=str(meta.get("compound_name", meta.get("name", "Unknown"))),
                inchikey=str(meta.get("inchikey", "")),
                formula=str(meta.get("formula", "")),
                adduct=str(meta.get("adduct", meta.get("precursor_type", ""))),
                score=round(best_score, 4),
                n_matched_peaks=best_n_matched,
                library_source=source_str,
                data_type=data_type,
                msi_level=_assign_msi_level(best_score, data_type),
            ))

    return hits

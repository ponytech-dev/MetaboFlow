"""SIRIUS CLI wrapper: converts API requests to CLI calls and parses output."""

from __future__ import annotations

import csv
import logging
import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

from app.config import settings
from app.models import (
    FormulaCandidate,
    MS2Spectrum,
    PredictionResult,
    StructureCandidate,
)

logger = logging.getLogger(__name__)


def _write_ms_file(spectrum: MS2Spectrum, output_path: str) -> None:
    """Write a single spectrum in SIRIUS .ms format."""
    with open(output_path, "w") as f:
        f.write(f">compound {spectrum.feature_id}\n")
        f.write(f">parentmass {spectrum.precursor_mz}\n")
        f.write(f">ionization {spectrum.precursor_type}\n")
        f.write("\n")

        # MS1 isotope pattern (optional but improves formula prediction)
        if spectrum.ms1_mz_array:
            f.write(">ms1\n")
            for mz, intensity in zip(spectrum.ms1_mz_array, spectrum.ms1_intensity_array):
                f.write(f"{mz} {intensity}\n")
            f.write("\n")

        # MS2 fragmentation spectrum
        f.write(">ms2\n")
        for mz, intensity in zip(spectrum.ms2_mz_array, spectrum.ms2_intensity_array):
            f.write(f"{mz} {intensity}\n")
        f.write("\n")


def _parse_formula_results(tsv_path: str) -> dict[str, list[FormulaCandidate]]:
    """Parse formula_identifications.tsv from SIRIUS output."""
    results: dict[str, list[FormulaCandidate]] = {}

    if not os.path.exists(tsv_path):
        return results

    with open(tsv_path) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            fid = row.get("id", row.get("featureId", ""))
            # Extract feature_id from SIRIUS compound ID format
            if "_" in fid:
                fid = fid.rsplit("_", 1)[0]

            candidate = FormulaCandidate(
                molecular_formula=row.get("molecularFormula", ""),
                adduct=row.get("adduct", ""),
                sirius_score=float(row.get("SiriusScore", row.get("score", 0))),
                isotope_score=float(row.get("IsotopeScore", 0)),
                tree_score=float(row.get("TreeScore", 0)),
                zodiac_score=_safe_float(row.get("ZodiacScore")),
            )

            if fid not in results:
                results[fid] = []
            results[fid].append(candidate)

    return results


def _parse_structure_results(tsv_path: str) -> dict[str, list[StructureCandidate]]:
    """Parse structure_identifications.tsv from SIRIUS output."""
    results: dict[str, list[StructureCandidate]] = {}

    if not os.path.exists(tsv_path):
        return results

    with open(tsv_path) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            fid = row.get("id", row.get("featureId", ""))
            if "_" in fid:
                fid = fid.rsplit("_", 1)[0]

            candidate = StructureCandidate(
                inchikey=row.get("InChIkey2D", row.get("InChIKey", "")),
                inchi=row.get("InChI", ""),
                compound_name=row.get("name", row.get("moleculeName", "")),
                smiles=row.get("smiles", ""),
                molecular_formula=row.get("molecularFormula", ""),
                csi_score=float(row.get("CSI:FingerIDScore", row.get("score", 0))),
                tanimoto_similarity=float(row.get("TanimotoSimilarity", 0)),
            )

            if fid not in results:
                results[fid] = []
            results[fid].append(candidate)

    return results


def _safe_float(val) -> float | None:
    if val is None or val == "" or val == "N/A":
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


def login() -> bool:
    """Login to SIRIUS web services (required for CSI:FingerID)."""
    if not settings.sirius_user or not settings.sirius_password:
        logger.warning("SIRIUS credentials not configured, CSI:FingerID will not work")
        return False

    try:
        result = subprocess.run(
            [settings.sirius_bin, "login", "--user", settings.sirius_user,
             "--password", settings.sirius_password],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            logger.info("SIRIUS login successful")
            return True
        else:
            logger.error(f"SIRIUS login failed: {result.stderr}")
            return False
    except Exception as e:
        logger.error(f"SIRIUS login error: {e}")
        return False


def get_version() -> str:
    """Get SIRIUS version string."""
    try:
        result = subprocess.run(
            [settings.sirius_bin, "--version"],
            capture_output=True, text=True, timeout=10,
        )
        return result.stdout.strip().split("\n")[0] if result.returncode == 0 else "unknown"
    except Exception:
        return "not installed"


def predict(
    spectra: list[MS2Spectrum],
    database: str = "bio",
    max_candidates: int = 5,
    instrument: str = "orbitrap",
) -> list[PredictionResult]:
    """Run SIRIUS + CSI:FingerID on a batch of MS2 spectra.

    Args:
        spectra: List of MS2 spectra with precursor info.
        database: Structure database to search (bio, pubchem, kegg, hmdb).
        max_candidates: Maximum formula/structure candidates per compound.
        instrument: Instrument type for fragmentation tree scoring.

    Returns:
        List of PredictionResult with formula and structure candidates.
    """
    if not spectra:
        return []

    job_id = uuid.uuid4().hex[:8]
    job_dir = os.path.join(settings.work_dir, f"job_{job_id}")
    input_dir = os.path.join(job_dir, "input")
    output_dir = os.path.join(job_dir, "output")
    export_dir = os.path.join(job_dir, "export")
    os.makedirs(input_dir, exist_ok=True)
    os.makedirs(export_dir, exist_ok=True)

    try:
        # Write input .ms files
        for spec in spectra:
            ms_path = os.path.join(input_dir, f"{spec.feature_id}.ms")
            _write_ms_file(spec, ms_path)

        # Map instrument to SIRIUS profile
        profile_map = {
            "orbitrap": "orbitrap",
            "qtof": "qtof",
            "fticr": "orbitrap",  # FTICR uses same scoring as Orbitrap
        }
        profile = profile_map.get(instrument, "orbitrap")

        # Build SIRIUS command
        cmd = [
            settings.sirius_bin,
            "-i", input_dir,
            "-o", output_dir,
            "--maxmz", "2000",
            "formula",
            "-c", str(max_candidates),
            "-p", profile,
            "fingerprint",
            "structure",
            "--database", database,
            "canopus",
            "write-summaries",
            "--output", export_dir,
        ]

        logger.info(f"Running SIRIUS: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=settings.sirius_timeout,
        )

        if result.returncode != 0:
            logger.error(f"SIRIUS failed (exit {result.returncode}): {result.stderr[:500]}")
            # Still try to parse partial results
        else:
            logger.info("SIRIUS completed successfully")

        # Parse results from exported TSV files
        formula_tsv = _find_file(export_dir, "formula_identifications")
        structure_tsv = _find_file(export_dir, "structure_identifications")

        formula_results = _parse_formula_results(formula_tsv) if formula_tsv else {}
        structure_results = _parse_structure_results(structure_tsv) if structure_tsv else {}

        # Build prediction results
        predictions = []
        for spec in spectra:
            fid = spec.feature_id
            formulas = formula_results.get(fid, [])
            structures = structure_results.get(fid, [])

            pred = PredictionResult(
                feature_id=fid,
                precursor_mz=spec.precursor_mz,
                top_formula=formulas[0] if formulas else None,
                top_structure=structures[0] if structures else None,
                formula_candidates=formulas[:max_candidates],
                structure_candidates=structures[:max_candidates],
                msi_level=3 if structures else 4,
            )
            predictions.append(pred)

        return predictions

    finally:
        # Cleanup job directory
        shutil.rmtree(job_dir, ignore_errors=True)


def _find_file(directory: str, name_pattern: str) -> str | None:
    """Find a file matching a pattern in directory tree."""
    for root, _, files in os.walk(directory):
        for f in files:
            if name_pattern in f and (f.endswith(".tsv") or f.endswith(".csv")):
                return os.path.join(root, f)
    return None

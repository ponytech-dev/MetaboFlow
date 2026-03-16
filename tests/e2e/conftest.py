"""E2E test fixtures — real public metabolomics data."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest


DATA_DIR = Path(__file__).parent / "data"


# ── Metabolomics Workbench ST000001 ──────────────────────────────────────────


def _load_st000001() -> dict:
    """Load and parse ST000001 (Arabidopsis FatBIE, GC-MS, 24 samples × 107 metabolites)."""
    path = DATA_DIR / "st000001_mwtab.txt"
    if not path.exists():
        pytest.skip("ST000001 data not downloaded — run: curl -sL "
                     "'https://www.metabolomicsworkbench.org/rest/study/study_id/ST000001/mwtab' "
                     f"-o {path}")
    with open(path) as f:
        return json.load(f)


@pytest.fixture(scope="session")
def st000001_raw():
    """Raw parsed JSON from ST000001."""
    return _load_st000001()


@pytest.fixture(scope="session")
def st000001_arrays(st000001_raw):
    """Convert ST000001 to numpy arrays + metadata DataFrames.

    Returns (X, obs, var) where:
      X: ndarray (n_samples × n_features)
      obs: DataFrame with sample_id, group, batch, sample_type
      var: DataFrame with feature_id, mz, rt, compound_name, kegg_id
    """
    data = st000001_raw
    md = data["MS_METABOLITE_DATA"]
    metabolites_info = md["Metabolites"]
    data_rows = md["Data"]

    # Extract sample IDs from data rows (all keys except 'Metabolite')
    sample_ids = [k for k in data_rows[0].keys() if k != "Metabolite"]

    # Build intensity matrix: rows = metabolites, columns = samples
    raw_matrix = []
    for row in data_rows:
        values = []
        for sid in sample_ids:
            val = row.get(sid, "0")
            try:
                values.append(float(val))
            except (ValueError, TypeError):
                values.append(np.nan)
        raw_matrix.append(values)

    # X should be (n_samples × n_features) — transpose
    X = np.array(raw_matrix, dtype=np.float64).T

    # Build sample metadata from SUBJECT_SAMPLE_FACTORS
    factors = data["SUBJECT_SAMPLE_FACTORS"]
    sample_groups = {}
    for entry in factors:
        sid = entry["Sample ID"]
        # Use genotype as group
        genotype = entry["Factors"].get("Arabidopsis Genotype", "unknown")
        treatment = entry["Factors"].get("Plant Wounding Treatment", "unknown")
        sample_groups[sid] = f"{genotype}_{treatment}".replace(" ", "_")

    obs_rows = []
    for sid in sample_ids:
        obs_rows.append({
            "sample_id": sid,
            "group": sample_groups.get(sid, "unknown"),
            "batch": "batch1",
            "sample_type": "sample",
        })
    obs = pd.DataFrame(obs_rows)

    # Build feature metadata
    var_rows = []
    for i, m in enumerate(metabolites_info):
        var_rows.append({
            "feature_id": f"F{i+1:04d}",
            "mz": float(m.get("moverz_quant", 0)),
            "rt": float(m.get("ri", 0)),
            "compound_name": m.get("Metabolite", ""),
            "kegg_id": m.get("kegg_id", ""),
        })
    var = pd.DataFrame(var_rows)

    return X, obs, var


# ── Project example_results (MethiocarbB) ────────────────────────────────────


@pytest.fixture(scope="session")
def methiocarbB_csv():
    """Load the existing MethiocarbB differential peaks CSV from example_results."""
    path = Path(__file__).parent.parent.parent / "example_results" / "01_differential_peaks" / "MethiocarbB差异峰.csv"
    if not path.exists():
        pytest.skip("MethiocarbB data not found")
    return pd.read_csv(path)

"""Tests for MetaboData format converters (convert.py)."""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from metabodata.convert import (
    from_dataframe,
    from_feature_csv,
    from_mztabm,
    to_dataframe,
    to_feature_csv,
    to_mztabm,
)
from metabodata.core import MetaboData

# ──────────────────────────────────────────────────────────────────────────────
# Helpers / fixtures
# ──────────────────────────────────────────────────────────────────────────────


def _make_metabodata(
    n_samples: int = 4,
    n_features: int = 3,
    with_optional: bool = False,
    seed: int = 42,
) -> MetaboData:
    rng = np.random.default_rng(seed)
    X = rng.random((n_samples, n_features)).astype(np.float64) * 1e6

    sample_types = ["sample", "sample", "qc", "blank"]
    obs = pd.DataFrame(
        {
            "sample_id": [f"S{i+1}" for i in range(n_samples)],
            "group": (["ctrl", "treat"] * math.ceil(n_samples / 2))[:n_samples],
            "batch": ["batch1"] * n_samples,
            "sample_type": sample_types[:n_samples],
        }
    )

    var_data: dict = {
        "feature_id": [f"f{i+1}" for i in range(n_features)],
        "mz": [100.0505 + i * 100 for i in range(n_features)],
        "rt": [60.5 + i * 60 for i in range(n_features)],
    }
    if with_optional:
        var_data["compound_name"] = [f"Compound_{i+1}" for i in range(n_features)]
        var_data["hmdb_id"] = [f"HMDB0000{i+1:03d}" for i in range(n_features)]
        var_data["kegg_id"] = [f"C{i+1:05d}" for i in range(n_features)]
        var_data["adduct"] = ["[M+H]+" for _ in range(n_features)]
        var_data["msi_level"] = [1, 2, 3][:n_features]

    var = pd.DataFrame(var_data)
    return MetaboData(X=X, obs=obs, var=var)


# ──────────────────────────────────────────────────────────────────────────────
# 1. CSV round-trip — basic
# ──────────────────────────────────────────────────────────────────────────────


def test_csv_roundtrip_basic(tmp_path: Path) -> None:
    """to_feature_csv → from_feature_csv produces equivalent MetaboData."""
    md = _make_metabodata()
    csv_path = tmp_path / "features.csv"
    to_feature_csv(md, csv_path)

    assert csv_path.exists(), "CSV file was not created"

    sample_meta = {
        row["sample_id"]: {
            "group": row["group"],
            "batch": row["batch"],
            "sample_type": row["sample_type"],
        }
        for _, row in md.obs.iterrows()
    }
    md2 = from_feature_csv(csv_path, sample_meta=sample_meta)

    # Shape
    assert md2.X.shape == md.X.shape, "X shape mismatch after CSV round-trip"

    # Intensities (should be numerically identical through CSV serialisation)
    np.testing.assert_allclose(
        md2.X, md.X, rtol=1e-6,
        err_msg="Intensity matrix differs after CSV round-trip",
    )

    # Feature metadata
    assert list(md2.var["mz"]) == pytest.approx(list(md.var["mz"]), rel=1e-6)
    assert list(md2.var["rt"]) == pytest.approx(list(md.var["rt"]), rel=1e-6)

    # Sample IDs preserved
    assert list(md2.obs["sample_id"]) == list(md.obs["sample_id"])


# ──────────────────────────────────────────────────────────────────────────────
# 2. CSV round-trip — with optional var columns
# ──────────────────────────────────────────────────────────────────────────────


def test_csv_roundtrip_with_optional_columns(tmp_path: Path) -> None:
    """Optional var columns (compound_name, hmdb_id, …) survive CSV round-trip."""
    md = _make_metabodata(with_optional=True)
    csv_path = tmp_path / "features_opt.csv"
    to_feature_csv(md, csv_path)

    sample_meta = {
        row["sample_id"]: {"group": row["group"], "batch": row["batch"], "sample_type": row["sample_type"]}
        for _, row in md.obs.iterrows()
    }
    md2 = from_feature_csv(csv_path, sample_meta=sample_meta)

    assert "compound_name" in md2.var.columns
    assert list(md2.var["compound_name"]) == list(md.var["compound_name"])
    assert "hmdb_id" in md2.var.columns


# ──────────────────────────────────────────────────────────────────────────────
# 3. CSV file has .csv suffix auto-appended
# ──────────────────────────────────────────────────────────────────────────────


def test_csv_suffix_auto_appended(tmp_path: Path) -> None:
    """to_feature_csv appends .csv when path has no suffix."""
    md = _make_metabodata()
    to_feature_csv(md, tmp_path / "features")
    assert (tmp_path / "features.csv").exists()


# ──────────────────────────────────────────────────────────────────────────────
# 4. DataFrame round-trip
# ──────────────────────────────────────────────────────────────────────────────


def test_dataframe_roundtrip_basic() -> None:
    """to_dataframe → from_dataframe produces equivalent MetaboData."""
    md = _make_metabodata()
    df = to_dataframe(md)

    sample_cols = list(md.obs["sample_id"])
    md2 = from_dataframe(df, sample_cols=sample_cols)

    assert md2.X.shape == md.X.shape
    np.testing.assert_allclose(md2.X, md.X, rtol=1e-9)
    assert list(md2.var["mz"]) == pytest.approx(list(md.var["mz"]))
    assert list(md2.var["rt"]) == pytest.approx(list(md.var["rt"]))


# ──────────────────────────────────────────────────────────────────────────────
# 5. DataFrame round-trip — with optional columns
# ──────────────────────────────────────────────────────────────────────────────


def test_dataframe_roundtrip_optional_columns() -> None:
    """Optional var columns survive DataFrame round-trip."""
    md = _make_metabodata(with_optional=True)
    df = to_dataframe(md)

    sample_cols = list(md.obs["sample_id"])
    md2 = from_dataframe(df, sample_cols=sample_cols)

    assert "compound_name" in md2.var.columns
    assert "hmdb_id" in md2.var.columns
    assert list(md2.var["compound_name"]) == list(md.var["compound_name"])


# ──────────────────────────────────────────────────────────────────────────────
# 6. to_dataframe column ordering
# ──────────────────────────────────────────────────────────────────────────────


def test_to_dataframe_column_order() -> None:
    """to_dataframe puts var columns first, then sample intensities."""
    md = _make_metabodata()
    df = to_dataframe(md)

    sample_ids = list(md.obs["sample_id"])
    var_cols = list(md.var.columns)

    # All var columns appear before sample columns
    last_var_pos = max(df.columns.get_loc(c) for c in var_cols)
    first_sample_pos = min(df.columns.get_loc(c) for c in sample_ids)
    assert last_var_pos < first_sample_pos, "var columns must precede sample columns"


# ──────────────────────────────────────────────────────────────────────────────
# 7. mzTab-M export — section headers present
# ──────────────────────────────────────────────────────────────────────────────


def test_mztabm_export_section_headers(tmp_path: Path) -> None:
    """Exported mzTab-M file contains all required section prefixes."""
    md = _make_metabodata()
    out = tmp_path / "export.mzTab"
    to_mztabm(md, out)

    text = out.read_text(encoding="utf-8")
    for prefix in ("COM\t", "MTD\t", "SML\t", "SMF\t", "SME\t"):
        assert prefix in text, f"Section prefix '{prefix}' missing in mzTab-M output"


# ──────────────────────────────────────────────────────────────────────────────
# 8. mzTab-M export — required MTD keys
# ──────────────────────────────────────────────────────────────────────────────


def test_mztabm_export_mtd_required_keys(tmp_path: Path) -> None:
    """MTD section contains mandatory mzTab-M keys."""
    md = _make_metabodata()
    out = tmp_path / "export.mzTab"
    to_mztabm(md, out)

    text = out.read_text(encoding="utf-8")
    required_keys = [
        "mzTab-version",
        "mzTab-mode",
        "mzTab-type",
        "assay[1]-name",
        "ms_run[1]-location",
    ]
    for key in required_keys:
        assert f"MTD\t{key}\t" in text, f"MTD key '{key}' missing"


# ──────────────────────────────────────────────────────────────────────────────
# 9. mzTab-M export — SML row count matches n_features
# ──────────────────────────────────────────────────────────────────────────────


def test_mztabm_sml_row_count(tmp_path: Path) -> None:
    """SML section has exactly n_features data rows (excluding header)."""
    md = _make_metabodata(n_features=5)
    out = tmp_path / "export.mzTab"
    to_mztabm(md, out)

    sml_data_rows = [
        line for line in out.read_text().splitlines()
        if line.startswith("SML\t") and not line.split("\t")[1].startswith("SML_ID")
    ]
    assert len(sml_data_rows) == md.n_vars


# ──────────────────────────────────────────────────────────────────────────────
# 10. mzTab-M round-trip
# ──────────────────────────────────────────────────────────────────────────────


def test_mztabm_roundtrip(tmp_path: Path) -> None:
    """to_mztabm → from_mztabm recovers shape, intensities, mz, rt."""
    md = _make_metabodata(n_samples=3, n_features=4)
    out = tmp_path / "rt.mzTab"
    to_mztabm(md, out)

    md2 = from_mztabm(out)

    assert md2.X.shape == md.X.shape, "Shape mismatch after mzTab-M round-trip"
    np.testing.assert_allclose(
        md2.X, md.X, rtol=1e-6,
        err_msg="Intensities differ after mzTab-M round-trip",
    )
    np.testing.assert_allclose(md2.var["mz"].values, md.var["mz"].values, rtol=1e-6)
    np.testing.assert_allclose(md2.var["rt"].values, md.var["rt"].values, rtol=1e-6)
    assert list(md2.obs["sample_id"]) == list(md.obs["sample_id"])


# ──────────────────────────────────────────────────────────────────────────────
# 11. mzTab-M round-trip — with optional annotation columns
# ──────────────────────────────────────────────────────────────────────────────


def test_mztabm_roundtrip_with_annotations(tmp_path: Path) -> None:
    """Optional compound annotations survive mzTab-M round-trip."""
    md = _make_metabodata(n_samples=2, n_features=3, with_optional=True)
    out = tmp_path / "annotated.mzTab"
    to_mztabm(md, out)

    md2 = from_mztabm(out)

    assert "compound_name" in md2.var.columns
    assert list(md2.var["compound_name"]) == list(md.var["compound_name"])
    assert "hmdb_id" in md2.var.columns
    assert "kegg_id" in md2.var.columns


# ──────────────────────────────────────────────────────────────────────────────
# 12. Edge case — single sample
# ──────────────────────────────────────────────────────────────────────────────


def test_single_sample_csv_roundtrip(tmp_path: Path) -> None:
    """Single-sample MetaboData survives CSV round-trip."""
    rng = np.random.default_rng(0)
    X = rng.random((1, 3)).astype(np.float64) * 1e5
    obs = pd.DataFrame(
        {"sample_id": ["only_sample"], "group": ["ctrl"], "batch": ["b1"], "sample_type": ["sample"]}
    )
    var = pd.DataFrame(
        {"feature_id": ["f1", "f2", "f3"], "mz": [100.1, 200.2, 300.3], "rt": [10.0, 20.0, 30.0]}
    )
    md = MetaboData(X=X, obs=obs, var=var)

    csv_path = tmp_path / "single.csv"
    to_feature_csv(md, csv_path)
    md2 = from_feature_csv(
        csv_path,
        sample_meta={"only_sample": {"group": "ctrl", "batch": "b1", "sample_type": "sample"}},
    )

    assert md2.X.shape == (1, 3)
    np.testing.assert_allclose(md2.X, md.X, rtol=1e-6)


# ──────────────────────────────────────────────────────────────────────────────
# 13. Edge case — missing optional var columns
# ──────────────────────────────────────────────────────────────────────────────


def test_missing_optional_columns_mztabm(tmp_path: Path) -> None:
    """mzTab-M export/import works when optional var columns are absent."""
    md = _make_metabodata(with_optional=False)  # no compound_name etc.
    out = tmp_path / "no_annot.mzTab"
    to_mztabm(md, out)

    md2 = from_mztabm(out)

    # compound_name should not appear (no annotation in source)
    assert "compound_name" not in md2.var.columns or md2.var["compound_name"].isna().all()
    assert md2.X.shape == md.X.shape


# ──────────────────────────────────────────────────────────────────────────────
# 14. Edge case — NaN values in X
# ──────────────────────────────────────────────────────────────────────────────


def test_nan_values_in_X(tmp_path: Path) -> None:
    """NaN intensities are handled gracefully in CSV and mzTab-M exports."""
    rng = np.random.default_rng(7)
    X = rng.random((3, 4)).astype(np.float64) * 1e6
    X[0, 1] = float("nan")
    X[2, 3] = float("nan")

    obs = pd.DataFrame(
        {
            "sample_id": ["A", "B", "C"],
            "group": ["g1", "g1", "g2"],
            "batch": ["b1", "b1", "b1"],
            "sample_type": ["sample", "sample", "qc"],
        }
    )
    var = pd.DataFrame(
        {
            "feature_id": [f"f{i+1}" for i in range(4)],
            "mz": [100.0, 200.0, 300.0, 400.0],
            "rt": [10.0, 20.0, 30.0, 40.0],
        }
    )
    md = MetaboData(X=X, obs=obs, var=var)

    # CSV: NaN → empty cell → parsed as NaN again
    csv_path = tmp_path / "nan_test.csv"
    to_feature_csv(md, csv_path)
    sample_meta = {
        row["sample_id"]: {"group": row["group"], "batch": row["batch"], "sample_type": row["sample_type"]}
        for _, row in obs.iterrows()
    }
    md_csv = from_feature_csv(csv_path, sample_meta=sample_meta)
    assert np.isnan(md_csv.X[0, 1])
    assert np.isnan(md_csv.X[2, 3])

    # mzTab-M: NaN → "null" → parsed as NaN again
    mztab_path = tmp_path / "nan_test.mzTab"
    to_mztabm(md, mztab_path)
    md_mztab = from_mztabm(mztab_path)
    assert np.isnan(md_mztab.X[0, 1])
    assert np.isnan(md_mztab.X[2, 3])


# ──────────────────────────────────────────────────────────────────────────────
# 15. Column conflict detection
# ──────────────────────────────────────────────────────────────────────────────


def test_column_conflict_raises() -> None:
    """to_dataframe raises ValueError when var column names clash with sample IDs."""
    X = np.ones((2, 2))
    obs = pd.DataFrame(
        {"sample_id": ["mz", "rt"], "group": ["g1", "g2"], "batch": ["b1", "b1"], "sample_type": ["sample", "sample"]}
    )
    var = pd.DataFrame({"feature_id": ["f1", "f2"], "mz": [100.0, 200.0], "rt": [10.0, 20.0]})
    md = MetaboData(X=X, obs=obs, var=var)

    with pytest.raises(ValueError, match="Column name conflict"):
        to_dataframe(md)


# ──────────────────────────────────────────────────────────────────────────────
# 16. from_dataframe — custom mz/rt column names
# ──────────────────────────────────────────────────────────────────────────────


def test_from_dataframe_custom_mz_rt_cols() -> None:
    """from_dataframe correctly handles non-default mz/rt column names."""
    df = pd.DataFrame(
        {
            "feature_id": ["f1", "f2"],
            "m_over_z": [150.0, 250.0],
            "retention": [30.0, 60.0],
            "sample_A": [1000.0, 2000.0],
            "sample_B": [3000.0, 4000.0],
        }
    )
    md = from_dataframe(
        df,
        sample_cols=["sample_A", "sample_B"],
        mz_col="m_over_z",
        rt_col="retention",
    )

    assert "mz" in md.var.columns
    assert "rt" in md.var.columns
    assert list(md.var["mz"]) == pytest.approx([150.0, 250.0])
    assert md.X.shape == (2, 2)

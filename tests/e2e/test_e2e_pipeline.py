"""End-to-end tests using real public metabolomics data.

Data sources:
  - Metabolomics Workbench ST000001 (Arabidopsis FatBIE, GC-MS, 24 samples × 107 metabolites)
  - Project example_results/MethiocarbB (LC-MS, 6 samples × 125 features)

Tests cover the full MetaboFlow pipeline:
  1. Data loading → MetaboData construction
  2. MetaboData ↔ CSV round-trip
  3. MetaboData ↔ mzTab-M round-trip
  4. Backend API (create analysis, progress, engines, projects)
  5. Chart generation (PCA, volcano, heatmap, boxplot, pathway)
  6. Report generation
"""

from __future__ import annotations

import io
import json
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from metabodata.core import MetaboData
from metabodata.convert import (
    from_dataframe,
    from_feature_csv,
    to_dataframe,
    to_feature_csv,
    to_mztabm,
    from_mztabm,
)
from metabodata.io import save_metabodata, load_metabodata


# ═══════════════════════════════════════════════════════════════════════════════
# 1. MetaboData construction from real public data
# ═══════════════════════════════════════════════════════════════════════════════


class TestMetaboDataFromPublicData:
    """Build MetaboData from Metabolomics Workbench ST000001."""

    def test_construction_from_st000001(self, st000001_arrays):
        X, obs, var = st000001_arrays
        md = MetaboData(X=X, obs=obs, var=var)
        assert md.n_obs == 24
        assert md.n_vars == 107

    def test_sample_groups_correct(self, st000001_arrays):
        X, obs, var = st000001_arrays
        groups = obs["group"].unique()
        # 4 groups: 2 genotypes × 2 treatments
        assert len(groups) == 4

    def test_feature_metadata_populated(self, st000001_arrays):
        X, obs, var = st000001_arrays
        assert "compound_name" in var.columns
        assert "kegg_id" in var.columns
        # Most features should have compound names
        assert (var["compound_name"] != "").sum() > 100

    def test_intensity_matrix_no_negatives(self, st000001_arrays):
        X, obs, var = st000001_arrays
        assert np.all(X[~np.isnan(X)] >= 0)

    def test_intensity_matrix_reasonable_range(self, st000001_arrays):
        """GC-MS peak heights should be in a reasonable range."""
        X, obs, var = st000001_arrays
        assert X.max() > 100  # not all zeros
        assert X.min() >= 0

    def test_provenance_tracking(self, st000001_arrays):
        X, obs, var = st000001_arrays
        md = MetaboData(X=X, obs=obs, var=var)
        md.add_provenance_step(
            step="data_import",
            engine="metabolomics_workbench",
            engine_version="REST_API",
            params={"study_id": "ST000001", "analysis_id": "AN000001"},
        )
        assert len(md.uns["provenance"]["steps"]) == 1
        assert md.uns["provenance"]["steps"][0]["engine"] == "metabolomics_workbench"


# ═══════════════════════════════════════════════════════════════════════════════
# 2. MetaboData construction from project example_results
# ═══════════════════════════════════════════════════════════════════════════════


class TestMetaboDataFromExampleResults:
    """Build MetaboData from the existing MethiocarbB differential peaks."""

    def test_construction_from_methiocarbB(self, methiocarbB_csv):
        df = methiocarbB_csv
        # Extract sample columns (control1-3, MethiocarbB1-3)
        sample_cols = [c for c in df.columns if c.startswith(("control", "MethiocarbB"))]
        assert len(sample_cols) == 6

        # Build MetaboData
        X = df[sample_cols].values.T  # (6 × n_features)
        n_features = X.shape[1]

        obs = pd.DataFrame({
            "sample_id": sample_cols,
            "group": ["control"] * 3 + ["treatment"] * 3,
            "batch": ["b1"] * 6,
            "sample_type": ["sample"] * 6,
        })

        var = pd.DataFrame({
            "feature_id": df["variable_id"].values,
            "mz": df["mz"].values,
            "rt": df["rt"].values,
        })
        # Add optional annotation columns if present
        if "Compound.name" in df.columns:
            var["compound_name"] = df["Compound.name"].values
        if "HMDB.ID" in df.columns:
            var["hmdb_id"] = df["HMDB.ID"].values
        if "KEGG.ID" in df.columns:
            var["kegg_id"] = df["KEGG.ID"].values
        if "Adduct" in df.columns:
            var["adduct"] = df["Adduct"].values

        md = MetaboData(X=X, obs=obs, var=var)
        assert md.n_obs == 6
        assert md.n_vars == n_features
        assert "compound_name" in md.var.columns

    def test_methiocarbB_has_differential_results(self, methiocarbB_csv):
        """The CSV should contain logFC, P.Value, adj.P.Val columns."""
        required = ["logFC", "P.Value", "adj.P.Val", "Significance"]
        for col in required:
            assert col in methiocarbB_csv.columns, f"Missing column: {col}"

    def test_methiocarbB_significance_counts(self, methiocarbB_csv):
        """Check that there are both significant and non-significant features."""
        sig_counts = methiocarbB_csv["Significance"].value_counts()
        assert "Up" in sig_counts.index or "Down" in sig_counts.index
        assert len(methiocarbB_csv) > 50  # Should have many features


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Format conversion round-trips with real data
# ═══════════════════════════════════════════════════════════════════════════════


class TestFormatConversionsRealData:
    """Test CSV and mzTab-M conversions with real metabolomics data."""

    def _build_md(self, st000001_arrays) -> MetaboData:
        X, obs, var = st000001_arrays
        return MetaboData(X=X, obs=obs, var=var)

    def test_csv_roundtrip_st000001(self, st000001_arrays, tmp_path):
        md = self._build_md(st000001_arrays)
        csv_path = tmp_path / "st000001.csv"
        to_feature_csv(md, csv_path)

        # Verify CSV file is readable
        df = pd.read_csv(csv_path)
        assert len(df) == 107  # features as rows
        assert "mz" in df.columns
        assert "rt" in df.columns

        # Round-trip back
        md2 = from_feature_csv(csv_path)
        assert md2.n_vars == md.n_vars
        assert md2.n_obs == md.n_obs
        np.testing.assert_allclose(md2.X, md.X, rtol=1e-6)

    def test_hdf5_roundtrip_st000001(self, st000001_arrays, tmp_path):
        md = self._build_md(st000001_arrays)
        h5_path = tmp_path / "st000001.metabodata"
        save_metabodata(md, str(h5_path))

        md2 = load_metabodata(str(h5_path))
        assert md2.n_obs == 24
        assert md2.n_vars == 107
        np.testing.assert_array_equal(md2.X, md.X)
        assert list(md2.obs["sample_id"]) == list(md.obs["sample_id"])

    def test_mztabm_export_st000001(self, st000001_arrays, tmp_path):
        md = self._build_md(st000001_arrays)
        mztab_path = tmp_path / "st000001.mzTab"
        to_mztabm(md, mztab_path)

        content = mztab_path.read_text()
        # Verify required sections
        assert "COM\t" in content or "MTD\t" in content
        assert "SML\t" in content
        assert "SMF\t" in content
        # Should have 107 SMF data rows
        smf_lines = [l for l in content.split("\n") if l.startswith("SMF\t") and not l.startswith("SMF\tSMF_ID")]
        # Header + data
        assert len(smf_lines) >= 107

    def test_mztabm_roundtrip_st000001(self, st000001_arrays, tmp_path):
        md = self._build_md(st000001_arrays)
        mztab_path = tmp_path / "st000001.mzTab"
        to_mztabm(md, mztab_path)
        md2 = from_mztabm(mztab_path)

        assert md2.n_vars == md.n_vars
        assert md2.n_obs == md.n_obs
        # Intensities should be preserved
        np.testing.assert_allclose(md2.X, md.X, rtol=1e-6, equal_nan=True)

    def test_dataframe_roundtrip_st000001(self, st000001_arrays):
        md = self._build_md(st000001_arrays)
        df = to_dataframe(md)
        assert len(df) == 107
        assert "compound_name" in df.columns

        sample_cols = list(md.obs["sample_id"])
        md2 = from_dataframe(df, sample_cols=sample_cols)
        assert md2.n_vars == md.n_vars
        np.testing.assert_allclose(md2.X, md.X, rtol=1e-6)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Backend API E2E with real data
# ═══════════════════════════════════════════════════════════════════════════════


class TestBackendAPIWithRealData:
    """Test backend API endpoints using real metabolomics data."""

    @pytest.fixture(autouse=True)
    def _ensure_db(self):
        from app.db.base import init_db
        init_db()

    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app
        return TestClient(app)

    def test_create_analysis_with_real_metadata(self, client):
        """Create an analysis with real sample metadata from ST000001."""
        config = {
            "sample_metadata": [
                {"sample_id": "LabF_115873", "group": "Ws_Control", "batch": "b1", "sample_type": "sample"},
                {"sample_id": "LabF_115878", "group": "Ws_Control", "batch": "b1", "sample_type": "sample"},
                {"sample_id": "LabF_115904", "group": "fatb_Wounded", "batch": "b1", "sample_type": "sample"},
                {"sample_id": "LabF_115909", "group": "fatb_Wounded", "batch": "b1", "sample_type": "sample"},
            ],
        }
        resp = client.post("/api/v1/analyses", json=config)
        assert resp.status_code == 200
        aid = resp.json()["analysis_id"]
        assert len(aid) == 8

        # Verify progress is initialized
        resp = client.get(f"/api/v1/analyses/{aid}/progress")
        assert resp.status_code == 200
        assert resp.json()["status"] == "pending"
        assert resp.json()["total_steps"] == 7

    def test_full_analysis_lifecycle(self, client):
        """Create → check progress → check result → list → project association."""
        # Create
        config = {"sample_metadata": [
            {"sample_id": "s1", "group": "control", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "s2", "group": "treatment", "batch": "b1", "sample_type": "sample"},
        ]}
        resp = client.post("/api/v1/analyses", json=config)
        aid = resp.json()["analysis_id"]

        # Create project and associate
        resp = client.post("/api/v1/projects", json={"name": "ST000001 Analysis", "description": "FatBIE study"})
        assert resp.status_code == 201
        pid = resp.json()["id"]

        resp = client.post(f"/api/v1/projects/{pid}/analyses/{aid}")
        assert resp.status_code == 200

        # Verify association
        resp = client.get(f"/api/v1/projects/{pid}")
        assert aid in resp.json()["analysis_ids"]

        # Check report endpoint
        resp = client.get(f"/api/v1/analyses/{aid}/report")
        assert resp.status_code == 200
        assert "MetaboFlow" in resp.text

        # Check methods endpoint
        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        assert resp.status_code == 200
        methods_data = resp.json(); assert "methods" in methods_data or "paragraph" in methods_data

    def test_engine_listing(self, client):
        """All 5 engines should be registered."""
        resp = client.get("/api/v1/engines")
        assert resp.status_code == 200
        engines = resp.json()
        names = {e["name"] for e in engines}
        assert names >= {"xcms", "stats", "mzmine", "pyopenms", "msdial"}

    def test_format_conversion_api(self, client, st000001_arrays, tmp_path):
        """Test CSV → MetaboData conversion via API.

        The API expects: first col = sample IDs, remaining cols = feature intensities.
        """
        X, obs, var = st000001_arrays
        # Build a simple CSV: samples × features (API format)
        csv_path = tmp_path / "upload.csv"
        feature_names = [f"F{i:04d}" for i in range(X.shape[1])]
        header = "sample_id," + ",".join(feature_names)
        lines = [header]
        for i, sid in enumerate(obs["sample_id"]):
            vals = ",".join(str(v) for v in X[i])
            lines.append(f"{sid},{vals}")
        csv_path.write_text("\n".join(lines))

        with open(csv_path, "rb") as f:
            resp = client.post(
                "/api/v1/convert/csv-to-metabodata",
                files={"file": ("test.csv", f, "text/csv")},
            )
        assert resp.status_code == 200
        assert resp.headers["content-type"] in (
            "application/x-hdf5", "application/x-hdf",
            "application/octet-stream",
        )

    def test_list_formats(self, client):
        resp = client.get("/api/v1/convert/formats")
        assert resp.status_code == 200
        formats = resp.json()
        names = [f["name"] for f in formats]
        assert "csv" in names or "CSV" in names


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Chart generation with real data
# ═══════════════════════════════════════════════════════════════════════════════


class TestChartGenerationRealData:
    """Test chart generation functions with real metabolomics data."""

    @pytest.fixture(autouse=True)
    def _setup_matplotlib(self):
        import matplotlib
        matplotlib.use("Agg")

    def test_pca_plot_st000001(self, st000001_arrays):
        from chart_service.plots.pca import plot_pca

        X, obs, var = st000001_arrays
        groups = list(obs["group"])

        fig = plot_pca(X, groups, title="ST000001 PCA")
        assert fig is not None
        ax = fig.axes[0]
        assert "PC1" in ax.get_xlabel()
        assert "PC2" in ax.get_ylabel()

    def test_volcano_plot_methiocarbB(self, methiocarbB_csv):
        from chart_service.plots.volcano import plot_volcano

        df = methiocarbB_csv
        log2fc = df["logFC"].values
        pvalues = df["P.Value"].values
        names = df["variable_id"].tolist()

        fig = plot_volcano(log2fc, pvalues, names, fc_cutoff=1.0, p_cutoff=0.05)
        assert fig is not None
        ax = fig.axes[0]
        assert "log2" in ax.get_xlabel().lower() or "fold" in ax.get_xlabel().lower()

    def test_heatmap_st000001(self, st000001_arrays):
        from chart_service.plots.heatmap import plot_heatmap

        X, obs, var = st000001_arrays
        # Use top 20 features for manageable heatmap
        top_idx = np.argsort(X.std(axis=0))[-20:]
        X_top = X[:, top_idx]
        feature_labels = [var.iloc[i]["compound_name"] for i in top_idx]
        sample_labels = list(obs["sample_id"])
        groups = list(obs["group"])

        fig = plot_heatmap(X_top, sample_labels, feature_labels, groups=groups)
        assert fig is not None

    def test_boxplot_real_feature(self, st000001_arrays):
        from chart_service.plots.boxplot import plot_feature_boxplot

        X, obs, var = st000001_arrays
        # Pick first feature
        intensities = X[:, 0]
        groups = list(obs["group"])
        feature_name = var.iloc[0]["compound_name"]

        fig = plot_feature_boxplot(intensities, groups, feature_name)
        assert fig is not None

    def test_pathway_bubble_mock(self):
        """Test pathway bubble chart with realistic mock data."""
        from chart_service.plots.pathway import plot_pathway_bubble

        pathway_names = [
            "Glycolysis / Gluconeogenesis",
            "Citrate cycle (TCA cycle)",
            "Pentose phosphate pathway",
            "Fatty acid biosynthesis",
            "Amino sugar and nucleotide sugar metabolism",
        ]
        fold_enrichment = np.array([3.2, 2.8, 2.1, 1.9, 1.5])
        pvalues = np.array([0.001, 0.003, 0.01, 0.02, 0.04])
        hit_counts = [8, 6, 5, 4, 3]

        fig = plot_pathway_bubble(pathway_names, fold_enrichment, pvalues, hit_counts)
        assert fig is not None

    def test_pca_plot_saves_to_png(self, st000001_arrays, tmp_path):
        from chart_service.plots.pca import plot_pca
        from chart_service.plots.base import save_plot

        X, obs, var = st000001_arrays
        fig = plot_pca(X, list(obs["group"]))
        png_path = tmp_path / "pca.png"
        save_plot(fig, str(png_path))
        assert png_path.exists()
        assert png_path.stat().st_size > 1000  # not trivially small

    def test_volcano_saves_to_png(self, methiocarbB_csv, tmp_path):
        from chart_service.plots.volcano import plot_volcano
        from chart_service.plots.base import save_plot

        df = methiocarbB_csv
        fig = plot_volcano(df["logFC"].values, df["P.Value"].values, df["variable_id"].tolist())
        png_path = tmp_path / "volcano.png"
        save_plot(fig, str(png_path))
        assert png_path.exists()
        assert png_path.stat().st_size > 1000


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Report generation with real data
# ═══════════════════════════════════════════════════════════════════════════════


class TestReportGenerationRealData:
    """Test report generation using real analysis data."""

    @pytest.fixture(autouse=True)
    def _ensure_db(self):
        from app.db.base import init_db
        init_db()

    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app
        return TestClient(app)

    def test_report_with_real_sample_names(self, client):
        config = {"sample_metadata": [
            {"sample_id": "LabF_115873", "group": "Ws_Control", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "LabF_115878", "group": "Ws_Control", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "LabF_115883", "group": "Ws_Control", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "LabF_115904", "group": "fatb_Wounded", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "LabF_115909", "group": "fatb_Wounded", "batch": "b1", "sample_type": "sample"},
            {"sample_id": "LabF_115914", "group": "fatb_Wounded", "batch": "b1", "sample_type": "sample"},
        ]}
        resp = client.post("/api/v1/analyses", json=config)
        aid = resp.json()["analysis_id"]

        # Generate report
        resp = client.get(f"/api/v1/analyses/{aid}/report")
        assert resp.status_code == 200
        html = resp.text
        assert "MetaboFlow" in html
        assert "Analysis Configuration" in html or "Configuration" in html

    def test_methods_paragraph_has_engine_info(self, client):
        config = {"sample_metadata": [
            {"sample_id": "s1", "group": "control", "batch": "b1", "sample_type": "sample"},
        ]}
        resp = client.post("/api/v1/analyses", json=config)
        aid = resp.json()["analysis_id"]

        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        assert resp.status_code == 200
        data = resp.json()
        key = "methods" if "methods" in data else "paragraph"; assert len(data[key]) > 0

    def test_report_download(self, client):
        config = {"sample_metadata": [
            {"sample_id": "s1", "group": "control", "batch": "b1", "sample_type": "sample"},
        ]}
        resp = client.post("/api/v1/analyses", json=config)
        aid = resp.json()["analysis_id"]

        resp = client.get(f"/api/v1/analyses/{aid}/report/download")
        assert resp.status_code == 200
        assert "attachment" in resp.headers.get("content-disposition", "")

"""Tests for chart_service plot functions and API endpoints.

Covers:
- Each plot function produces a valid matplotlib Figure.
- Edge cases: single group, minimal data, boundary p-values.
- API endpoints return HTTP 200 with image/png content type.
"""

from __future__ import annotations

import numpy as np
from fastapi.testclient import TestClient
from matplotlib.figure import Figure

from chart_service.main import app
from chart_service.plots import (
    figure_to_bytes,
    group_color_map,
    plot_feature_boxplot,
    plot_heatmap,
    plot_pathway_bubble,
    plot_pca,
    plot_volcano,
)

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

RNG = np.random.default_rng(0)

N_SAMPLES = 20
N_FEATURES = 30

X_MULTI = RNG.standard_normal((N_SAMPLES, N_FEATURES))
GROUPS_MULTI = ["Group_A"] * 10 + ["Group_B"] * 10

X_SINGLE = RNG.standard_normal((8, N_FEATURES))
GROUPS_SINGLE = ["Control"] * 8

SAMPLE_LABELS = [f"S{i:02d}" for i in range(N_SAMPLES)]
FEATURE_LABELS = [f"F{i:03d}" for i in range(N_FEATURES)]

LOG2FC = RNG.normal(0, 1.5, 50)
PVALUES = RNG.uniform(0, 1, 50)
FEAT_NAMES = [f"metabolite_{i}" for i in range(50)]

client = TestClient(app)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _is_valid_figure(fig: Figure) -> bool:
    """True if fig is a non-empty matplotlib Figure."""
    return isinstance(fig, Figure) and len(fig.axes) > 0


# ===========================================================================
# 1. plot_pca — multi-group
# ===========================================================================

def test_pca_multi_group() -> None:
    fig = plot_pca(X_MULTI, GROUPS_MULTI)
    assert _is_valid_figure(fig)


# ===========================================================================
# 2. plot_pca — single group (no crash, ellipse skipped for <3 pts handled)
# ===========================================================================

def test_pca_single_group() -> None:
    fig = plot_pca(X_SINGLE, GROUPS_SINGLE)
    assert _is_valid_figure(fig)


# ===========================================================================
# 3. plot_pca — axis labels contain variance explained
# ===========================================================================

def test_pca_axis_labels_contain_variance() -> None:
    fig = plot_pca(X_MULTI, GROUPS_MULTI, title="My PCA")
    ax = fig.axes[0]
    assert "%" in ax.get_xlabel()
    assert "%" in ax.get_ylabel()
    assert "My PCA" in ax.get_title()


# ===========================================================================
# 4. plot_volcano — standard case
# ===========================================================================

def test_volcano_standard() -> None:
    fig = plot_volcano(LOG2FC, PVALUES, FEAT_NAMES)
    assert _is_valid_figure(fig)


# ===========================================================================
# 5. plot_volcano — all p=1 (nothing significant)
# ===========================================================================

def test_volcano_no_significant() -> None:
    fig = plot_volcano(LOG2FC, np.ones(50), FEAT_NAMES)
    assert _is_valid_figure(fig)


# ===========================================================================
# 6. plot_heatmap — with groups
# ===========================================================================

def test_heatmap_with_groups() -> None:
    fig = plot_heatmap(X_MULTI, SAMPLE_LABELS, FEATURE_LABELS, groups=GROUPS_MULTI)
    assert _is_valid_figure(fig)


# ===========================================================================
# 7. plot_heatmap — without groups
# ===========================================================================

def test_heatmap_no_groups() -> None:
    fig = plot_heatmap(X_MULTI, SAMPLE_LABELS, FEATURE_LABELS, groups=None)
    assert _is_valid_figure(fig)


# ===========================================================================
# 8. plot_feature_boxplot — multi-group
# ===========================================================================

def test_boxplot_multi_group() -> None:
    intensities = RNG.standard_normal(N_SAMPLES)
    fig = plot_feature_boxplot(intensities, GROUPS_MULTI, feature_name="Glucose")
    assert _is_valid_figure(fig)


# ===========================================================================
# 9. plot_feature_boxplot — single group
# ===========================================================================

def test_boxplot_single_group() -> None:
    intensities = RNG.standard_normal(8)
    fig = plot_feature_boxplot(intensities, GROUPS_SINGLE, feature_name="Alanine")
    assert _is_valid_figure(fig)


# ===========================================================================
# 10. plot_pathway_bubble — standard case
# ===========================================================================

def test_pathway_bubble_standard() -> None:
    n = 15
    names = [f"Pathway_{i}" for i in range(n)]
    fe = RNG.uniform(1, 5, n)
    pv = RNG.uniform(0.001, 0.1, n)
    hits = RNG.integers(2, 30, n).tolist()
    fig = plot_pathway_bubble(names, fe, pv, hits)
    assert _is_valid_figure(fig)


# ===========================================================================
# 11. plot_pathway_bubble — top_n smaller than dataset
# ===========================================================================

def test_pathway_bubble_top_n() -> None:
    n = 30
    names = [f"Pathway_{i}" for i in range(n)]
    fe = RNG.uniform(1, 5, n)
    pv = RNG.uniform(0.001, 0.1, n)
    hits = RNG.integers(2, 30, n).tolist()
    fig = plot_pathway_bubble(names, fe, pv, hits, top_n=5)
    assert _is_valid_figure(fig)


# ===========================================================================
# 12. figure_to_bytes returns valid PNG bytes
# ===========================================================================

def test_figure_to_bytes_produces_png() -> None:
    fig = plot_pca(X_MULTI, GROUPS_MULTI)
    data = figure_to_bytes(fig)
    # PNG magic bytes
    assert data[:4] == b"\x89PNG"


# ===========================================================================
# 13. group_color_map uses NATURE_COLORS
# ===========================================================================

def test_group_color_map() -> None:
    cmap = group_color_map(["A", "B", "A", "C"])
    assert set(cmap.keys()) == {"A", "B", "C"}
    assert all(c.startswith("#") for c in cmap.values())


# ===========================================================================
# API endpoint tests
# ===========================================================================

def test_health_endpoint() -> None:
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_api_pca_returns_png() -> None:
    payload = {"X": X_MULTI.tolist(), "groups": GROUPS_MULTI, "title": "Test PCA"}
    r = client.post("/charts/pca", json=payload)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"
    assert r.content[:4] == b"\x89PNG"


def test_api_volcano_returns_png() -> None:
    payload = {
        "log2fc": LOG2FC.tolist(),
        "pvalues": PVALUES.tolist(),
        "names": FEAT_NAMES,
        "fc_cutoff": 1.0,
        "p_cutoff": 0.05,
    }
    r = client.post("/charts/volcano", json=payload)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"


def test_api_heatmap_returns_png() -> None:
    payload = {
        "X": X_MULTI.tolist(),
        "sample_labels": SAMPLE_LABELS,
        "feature_labels": FEATURE_LABELS,
        "groups": GROUPS_MULTI,
    }
    r = client.post("/charts/heatmap", json=payload)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"


def test_api_boxplot_returns_png() -> None:
    intensities = RNG.standard_normal(N_SAMPLES).tolist()
    payload = {"intensities": intensities, "groups": GROUPS_MULTI, "feature_name": "Glucose"}
    r = client.post("/charts/boxplot", json=payload)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"


def test_api_pathway_returns_png() -> None:
    n = 10
    payload = {
        "pathway_names": [f"Pathway_{i}" for i in range(n)],
        "fold_enrichment": RNG.uniform(1, 5, n).tolist(),
        "pvalues": RNG.uniform(0.001, 0.05, n).tolist(),
        "hit_counts": RNG.integers(2, 20, n).tolist(),
        "top_n": 10,
    }
    r = client.post("/charts/pathway", json=payload)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"


# ===========================================================================
# Edge case: mismatched array lengths raise 422
# ===========================================================================

def test_api_volcano_mismatched_lengths_returns_422() -> None:
    payload = {
        "log2fc": [1.0, -1.0],
        "pvalues": [0.01],  # wrong length
        "names": ["A", "B"],
    }
    r = client.post("/charts/volcano", json=payload)
    assert r.status_code == 422


def test_api_pca_insufficient_samples_returns_422() -> None:
    payload = {"X": [[1.0, 2.0]], "groups": ["A"]}  # only 1 sample
    r = client.post("/charts/pca", json=payload)
    assert r.status_code == 422

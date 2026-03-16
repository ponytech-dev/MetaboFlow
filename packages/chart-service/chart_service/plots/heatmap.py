"""Clustered heatmap with dendrograms and optional group color bar."""

from __future__ import annotations

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure
from scipy.cluster.hierarchy import dendrogram, linkage
from scipy.spatial.distance import pdist

from .base import group_color_map


def _linkage_matrix(
    data: np.ndarray, method: str = "ward", metric: str = "euclidean",
) -> np.ndarray:
    """Compute hierarchical linkage, handling degenerate cases."""
    if data.shape[0] < 2:
        return np.empty((0, 4))
    dist = pdist(data, metric=metric)
    return linkage(dist, method=method)


def plot_heatmap(
    X: np.ndarray,
    sample_labels: list[str],
    feature_labels: list[str],
    groups: list[str] | None = None,
    z_score: bool = True,
) -> Figure:
    """Generate a clustered heatmap with row/column dendrograms.

    Columns = samples, rows = features.
    A group color bar is added above the heatmap when *groups* is provided.

    Args:
        X: Intensity matrix, shape (n_samples, n_features).
        sample_labels: Sample names, length n_samples.
        feature_labels: Feature names, length n_features.
        groups: Group label per sample; drives the color bar. Optional.
        z_score: If True, z-score each feature (row-wise) before plotting.

    Returns:
        Matplotlib Figure.
    """
    X = np.asarray(X, dtype=float)
    n_samples, n_features = X.shape

    if len(sample_labels) != n_samples:
        raise ValueError("len(sample_labels) must equal X.shape[0]")
    if len(feature_labels) != n_features:
        raise ValueError("len(feature_labels) must equal X.shape[1]")
    if groups is not None and len(groups) != n_samples:
        raise ValueError("len(groups) must equal X.shape[0]")

    # Z-score across samples for each feature
    Xplot = X.T.copy()  # shape (n_features, n_samples) — rows=features for heatmap
    if z_score and n_samples > 1:
        mu = Xplot.mean(axis=1, keepdims=True)
        sd = Xplot.std(axis=1, keepdims=True, ddof=1)
        sd[sd == 0] = 1.0
        Xplot = (Xplot - mu) / sd

    # Hierarchical clustering
    col_link = _linkage_matrix(X)            # cluster samples (columns)
    row_link = _linkage_matrix(X.T)          # cluster features (rows)

    col_order: list[int]
    row_order: list[int]

    if col_link.size > 0 and n_samples > 1:
        col_dend = dendrogram(col_link, no_plot=True)
        col_order = col_dend["leaves"]
    else:
        col_order = list(range(n_samples))

    if row_link.size > 0 and n_features > 1:
        row_dend = dendrogram(row_link, no_plot=True)
        row_order = row_dend["leaves"]
    else:
        row_order = list(range(n_features))

    Xplot = Xplot[np.ix_(row_order, col_order)]
    ordered_samples = [sample_labels[i] for i in col_order]
    ordered_features = [feature_labels[i] for i in row_order]
    ordered_groups = [groups[i] for i in col_order] if groups else None

    # ------------------------------------------------------------------ layout
    has_groups = ordered_groups is not None
    row_dend_h = 0.15
    col_dend_w = 0.15
    colorbar_h = 0.04 if has_groups else 0.0
    heatmap_h = 0.81 - colorbar_h
    heatmap_w = 0.75

    fig = plt.figure(figsize=(max(6, n_samples * 0.25 + 2), max(5, n_features * 0.18 + 2)))

    # Column dendrogram (top-left of heatmap area)
    ax_col_dend = fig.add_axes([col_dend_w, row_dend_h + heatmap_h + colorbar_h, heatmap_w, 0.10])
    if col_link.size > 0 and n_samples > 1:
        dendrogram(col_link, ax=ax_col_dend, link_color_func=lambda _k: "#555555", no_labels=True)
    ax_col_dend.axis("off")

    # Row dendrogram (left of heatmap)
    ax_row_dend = fig.add_axes([0.02, row_dend_h, col_dend_w - 0.02, heatmap_h])
    if row_link.size > 0 and n_features > 1:
        dendrogram(
            row_link,
            ax=ax_row_dend,
            orientation="left",
            link_color_func=lambda _k: "#555555",
            no_labels=True,
        )
    ax_row_dend.axis("off")

    # Group color bar
    if has_groups:
        ax_cbar = fig.add_axes([col_dend_w, row_dend_h + heatmap_h, heatmap_w, colorbar_h])
        color_map = group_color_map(ordered_groups)  # type: ignore[arg-type]
        bar_colors = [color_map[g] for g in ordered_groups]  # type: ignore[index]
        for i, c in enumerate(bar_colors):
            ax_cbar.add_patch(
                mpatches.Rectangle(
                    (i / n_samples, 0), 1 / n_samples, 1, color=c, transform=ax_cbar.transAxes,
                )
            )
        ax_cbar.set_xlim(0, 1)
        ax_cbar.set_ylim(0, 1)
        ax_cbar.axis("off")
        # Legend
        handles = [mpatches.Patch(color=c, label=g) for g, c in color_map.items()]
        ax_cbar.legend(
            handles=handles,
            loc="lower right",
            bbox_to_anchor=(1.0, 1.05),
            fontsize=7,
            frameon=False,
            ncol=len(color_map),
            handlelength=1,
        )

    # Heatmap
    ax_heat = fig.add_axes([col_dend_w, row_dend_h, heatmap_w, heatmap_h])
    vmax = np.nanpercentile(np.abs(Xplot), 98)
    im = ax_heat.imshow(
        Xplot,
        aspect="auto",
        cmap="bwr",
        vmin=-vmax,
        vmax=vmax,
        interpolation="nearest",
    )
    ax_heat.set_xticks(range(n_samples))
    ax_heat.set_xticklabels(ordered_samples, rotation=45, ha="right", fontsize=7)
    ax_heat.set_yticks(range(n_features))
    ax_heat.set_yticklabels(ordered_features, fontsize=max(4, min(7, 60 // n_features)))
    ax_heat.tick_params(length=0)

    # Colorbar
    cbar_ax = fig.add_axes([col_dend_w + heatmap_w + 0.01, row_dend_h, 0.02, heatmap_h])
    cbar = fig.colorbar(im, cax=cbar_ax)
    cbar.ax.tick_params(labelsize=7)
    cbar.set_label("Z-score" if z_score else "Intensity", fontsize=7)

    return fig

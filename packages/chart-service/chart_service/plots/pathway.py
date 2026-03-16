"""Pathway enrichment bubble chart."""

from __future__ import annotations

import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure

# Pathway gradient: yellow → deep purple (matching config.R pathway_gradient)
_PATHWAY_CMAP_COLORS = ["#FDE725", "#35B779", "#31688E", "#440154"]
_PATHWAY_CMAP = mcolors.LinearSegmentedColormap.from_list("pathway", _PATHWAY_CMAP_COLORS)


def plot_pathway_bubble(
    pathway_names: list[str],
    fold_enrichment: np.ndarray,
    pvalues: np.ndarray,
    hit_counts: list[int],
    top_n: int = 20,
) -> Figure:
    """Generate a pathway enrichment bubble chart.

    Layout:
    - x-axis: fold enrichment
    - y-axis: pathway name (sorted by ascending p-value)
    - bubble size: hit count
    - bubble color: -log10(p-value) using viridis-like gradient

    Args:
        pathway_names: Pathway display names.
        fold_enrichment: Fold enrichment values, shape (n_pathways,).
        pvalues: Raw p-values, shape (n_pathways,).
        hit_counts: Number of hits per pathway.
        top_n: Display at most this many pathways (by ascending p-value).

    Returns:
        Matplotlib Figure.
    """
    fold_enrichment = np.asarray(fold_enrichment, dtype=float)
    pvalues = np.asarray(pvalues, dtype=float)
    hit_counts_arr = np.asarray(hit_counts, dtype=int)

    n = len(pathway_names)
    if not (fold_enrichment.shape == pvalues.shape == hit_counts_arr.shape == (n,)):
        raise ValueError("All arrays must have the same length as pathway_names")

    # Clip p-values
    pvalues = np.clip(pvalues, 1e-300, 1.0)
    neg_log10_p = -np.log10(pvalues)

    # Select top_n by ascending p-value
    if top_n > 0 and n > top_n:
        idx = np.argsort(pvalues)[:top_n]
    else:
        idx = np.argsort(pvalues)

    # Sort selected by descending p-value so most significant is at top of y-axis
    idx = idx[np.argsort(pvalues[idx])[::-1]]

    sel_names = [pathway_names[i] for i in idx]
    sel_fe = fold_enrichment[idx]
    sel_neg_log10 = neg_log10_p[idx]
    sel_hits = hit_counts_arr[idx]

    n_sel = len(idx)
    fig_h = max(4, n_sel * 0.35 + 1.5)
    fig, ax = plt.subplots(figsize=(7, fig_h))

    # Scale bubble area proportional to hit count
    size_scale = 300.0 / max(sel_hits.max(), 1)
    sizes = sel_hits * size_scale + 20  # minimum visible size

    sc = ax.scatter(
        sel_fe,
        range(n_sel),
        s=sizes,
        c=sel_neg_log10,
        cmap=_PATHWAY_CMAP,
        alpha=0.85,
        edgecolors="#444444",
        linewidths=0.5,
        zorder=3,
    )

    ax.set_yticks(range(n_sel))
    ax.set_yticklabels(sel_names, fontsize=8)
    ax.set_xlabel("Fold Enrichment", fontsize=9)
    ax.set_title("Pathway Enrichment", fontsize=10, pad=8)
    ax.grid(axis="x", color="#EEEEEE", linewidth=0.6, zorder=0)

    # Color bar for -log10(p)
    cbar = fig.colorbar(sc, ax=ax, pad=0.01, shrink=0.6)
    cbar.set_label("-log₁₀(p-value)", fontsize=8)
    cbar.ax.tick_params(labelsize=7)

    # Size legend
    hit_levels = sorted(set([sel_hits.min(), sel_hits.max(), int(np.median(sel_hits))]))
    legend_handles = [
        plt.scatter(
            [], [], s=h * size_scale + 20, c="#888888",
            alpha=0.7, edgecolors="#444444", linewidths=0.5,
        )
        for h in hit_levels
    ]
    ax.legend(
        legend_handles,
        [str(h) for h in hit_levels],
        title="Hits",
        loc="lower right",
        frameon=False,
        fontsize=7,
        title_fontsize=7,
        handletextpad=0.2,
        labelspacing=0.8,
    )

    fig.tight_layout()
    return fig

"""Volcano plot: log2 fold change vs -log10(p-value)."""

from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure

from .base import VOLCANO_COLORS


def plot_volcano(
    log2fc: np.ndarray,
    pvalues: np.ndarray,
    names: list[str],
    fc_cutoff: float = 1.0,
    p_cutoff: float = 0.05,
    top_n_labels: int = 10,
) -> Figure:
    """Generate a volcano plot.

    Points are coloured:
    - Up (red):   log2fc >=  fc_cutoff AND pvalue <= p_cutoff
    - Down (blue): log2fc <= -fc_cutoff AND pvalue <= p_cutoff
    - Not (gray): everything else

    Args:
        log2fc: Log2 fold change values, shape (n_features,).
        pvalues: Raw p-values (not -log10), shape (n_features,).
        names: Feature names, length n_features.
        fc_cutoff: Absolute log2FC threshold (default 1.0 = 2-fold).
        p_cutoff: P-value significance threshold (default 0.05).
        top_n_labels: Number of top significant features to label.

    Returns:
        Matplotlib Figure.
    """
    log2fc = np.asarray(log2fc, dtype=float)
    pvalues = np.asarray(pvalues, dtype=float)

    if log2fc.shape != pvalues.shape:
        raise ValueError("log2fc and pvalues must have the same shape")
    if len(names) != len(log2fc):
        raise ValueError("len(names) must match len(log2fc)")

    # Clip p-values to avoid log(0)
    pvalues = np.clip(pvalues, 1e-300, 1.0)
    neg_log10_p = -np.log10(pvalues)

    # Classify
    up_mask = (log2fc >= fc_cutoff) & (pvalues <= p_cutoff)
    down_mask = (log2fc <= -fc_cutoff) & (pvalues <= p_cutoff)
    ns_mask = ~(up_mask | down_mask)

    fig, ax = plt.subplots(figsize=(5, 4.5))

    # Plot each class
    for mask, label, color, zorder in [
        (ns_mask, "Not significant", VOLCANO_COLORS["Not"], 1),
        (down_mask, f"Down ({down_mask.sum()})", VOLCANO_COLORS["Down"], 2),
        (up_mask, f"Up ({up_mask.sum()})", VOLCANO_COLORS["Up"], 2),
    ]:
        if mask.any():
            ax.scatter(
                log2fc[mask],
                neg_log10_p[mask],
                c=color,
                label=label,
                s=12,
                alpha=0.7,
                edgecolors="none",
                zorder=zorder,
            )

    # Threshold lines
    p_thresh_line = -np.log10(p_cutoff)
    ax.axhline(p_thresh_line, color="#888888", linewidth=0.8, linestyle="--", zorder=0)
    ax.axvline(fc_cutoff, color="#888888", linewidth=0.8, linestyle="--", zorder=0)
    ax.axvline(-fc_cutoff, color="#888888", linewidth=0.8, linestyle="--", zorder=0)

    # Label top N significant features (by p-value, then by |FC|)
    sig_mask = up_mask | down_mask
    if sig_mask.any() and top_n_labels > 0:
        sig_indices = np.where(sig_mask)[0]
        # Sort by ascending p-value, then descending |FC|
        sort_key = np.lexsort((-np.abs(log2fc[sig_indices]), pvalues[sig_indices]))
        top_indices = sig_indices[sort_key[:top_n_labels]]

        for idx in top_indices:
            ax.annotate(
                names[idx],
                xy=(log2fc[idx], neg_log10_p[idx]),
                xytext=(3, 3),
                textcoords="offset points",
                fontsize=6,
                ha="left",
                va="bottom",
                color="#333333",
            )

    ax.set_xlabel("log₂ Fold Change", fontsize=9)
    ax.set_ylabel("-log₁₀(p-value)", fontsize=9)
    ax.set_title("Volcano Plot", fontsize=10, pad=8)

    ax.legend(frameon=False, fontsize=7, markerscale=1.5, handletextpad=0.3)

    fig.tight_layout()
    return fig

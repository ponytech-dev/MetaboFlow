"""Feature boxplot with strip plot overlay."""

from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure

from .base import group_color_map


def plot_feature_boxplot(
    intensities: np.ndarray,
    groups: list[str],
    feature_name: str = "Feature",
) -> Figure:
    """Generate a box + strip plot for a single feature, coloured by group.

    Args:
        intensities: Intensity values for each sample, shape (n_samples,).
        groups: Group label per sample, length n_samples.
        feature_name: Feature name used as y-axis label and title.

    Returns:
        Matplotlib Figure.
    """
    intensities = np.asarray(intensities, dtype=float)
    if intensities.ndim != 1:
        raise ValueError("intensities must be 1D")
    if len(groups) != len(intensities):
        raise ValueError("len(groups) must equal len(intensities)")

    unique_groups = list(dict.fromkeys(groups))  # preserve order
    color_map = group_color_map(groups)
    n_groups = len(unique_groups)

    fig, ax = plt.subplots(figsize=(max(3, n_groups * 0.9 + 1), 4))

    group_data = [intensities[np.array(groups) == g] for g in unique_groups]

    # Box plot (no fliers — points shown via strip)
    bp = ax.boxplot(
        group_data,
        positions=range(n_groups),
        widths=0.45,
        patch_artist=True,
        showfliers=False,
        medianprops=dict(color="black", linewidth=1.5),
        whiskerprops=dict(linewidth=0.8, color="#555555"),
        capprops=dict(linewidth=0.8, color="#555555"),
        boxprops=dict(linewidth=0.8),
    )

    # Fill boxes with group colors (semi-transparent)
    for patch, group in zip(bp["boxes"], unique_groups):
        patch.set_facecolor(color_map[group])
        patch.set_alpha(0.35)

    # Strip plot overlay — jitter horizontally
    rng = np.random.default_rng(42)
    for i, (group, data) in enumerate(zip(unique_groups, group_data)):
        jitter = rng.uniform(-0.12, 0.12, size=len(data))
        ax.scatter(
            i + jitter,
            data,
            c=color_map[group],
            s=18,
            alpha=0.75,
            edgecolors="white",
            linewidths=0.3,
            zorder=3,
        )

    ax.set_xticks(range(n_groups))
    ax.set_xticklabels(unique_groups, fontsize=8)
    ax.set_ylabel("Intensity", fontsize=9)
    ax.set_title(feature_name, fontsize=10, pad=6)

    fig.tight_layout()
    return fig

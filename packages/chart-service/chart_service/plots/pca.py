"""PCA score plot with 95% confidence ellipses."""

from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure
from matplotlib.patches import Ellipse
from scipy import linalg
from sklearn.decomposition import PCA

from .base import group_color_map


def _confidence_ellipse(
    ax: plt.Axes,
    x: np.ndarray,
    y: np.ndarray,
    color: str,
    n_std: float = 1.96,  # ~95%
    alpha: float = 0.15,
    lw: float = 1.2,
) -> None:
    """Draw a covariance confidence ellipse on *ax*.

    Uses eigendecomposition of the 2×2 covariance matrix.
    Silently skips if fewer than 3 points (ellipse undefined).

    Args:
        ax: Target axes.
        x: X coordinates.
        y: Y coordinates.
        color: Fill and edge color.
        n_std: Number of standard deviations (1.96 ≈ 95%).
        alpha: Fill transparency.
        lw: Edge line width.
    """
    if len(x) < 3:
        return

    cov = np.cov(x, y)
    eigenvalues, eigenvectors = linalg.eigh(cov)
    # Largest eigenvalue first
    order = eigenvalues.argsort()[::-1]
    eigenvalues = eigenvalues[order]
    eigenvectors = eigenvectors[:, order]

    angle = np.degrees(np.arctan2(*eigenvectors[:, 0][::-1]))
    width, height = 2 * n_std * np.sqrt(np.abs(eigenvalues))

    ellipse = Ellipse(
        xy=(np.mean(x), np.mean(y)),
        width=width,
        height=height,
        angle=angle,
        facecolor=color,
        edgecolor=color,
        alpha=alpha,
        linewidth=lw,
        linestyle="--",
    )
    ellipse.set_facecolor(color)
    ellipse.set_alpha(alpha)
    ax.add_patch(ellipse)

    # Dashed border without fill alpha confusion
    border = Ellipse(
        xy=(np.mean(x), np.mean(y)),
        width=width,
        height=height,
        angle=angle,
        facecolor="none",
        edgecolor=color,
        linewidth=lw,
        linestyle="--",
    )
    ax.add_patch(border)


def plot_pca(
    X: np.ndarray,
    groups: list[str],
    title: str = "PCA Score Plot",
    n_components: int = 2,
) -> Figure:
    """Generate a PCA score plot coloured by group with 95% confidence ellipses.

    Args:
        X: Feature intensity matrix, shape (n_samples, n_features).
           Rows are samples, columns are features.
        groups: Group label for each sample, length n_samples.
        title: Plot title.
        n_components: Number of PCA components to compute (at least 2 needed).

    Returns:
        Matplotlib Figure.
    """
    if X.ndim != 2 or X.shape[0] < 2:
        raise ValueError("X must be 2D with at least 2 samples")
    if len(groups) != X.shape[0]:
        raise ValueError("len(groups) must equal X.shape[0]")

    n_components = max(n_components, 2)
    n_components = min(n_components, min(X.shape))

    pca = PCA(n_components=n_components, random_state=42)
    scores = pca.fit_transform(X)
    var_exp = pca.explained_variance_ratio_ * 100

    color_map = group_color_map(groups)
    groups_arr = np.array(groups)

    fig, ax = plt.subplots(figsize=(5, 4))

    for group, color in color_map.items():
        mask = groups_arr == group
        xs = scores[mask, 0]
        ys = scores[mask, 1]
        ax.scatter(
            xs, ys, c=color, label=group, s=40,
            alpha=0.85, edgecolors="white", linewidths=0.4, zorder=3,
        )
        _confidence_ellipse(ax, xs, ys, color=color)

    ax.axhline(0, color="#CCCCCC", linewidth=0.6, zorder=1)
    ax.axvline(0, color="#CCCCCC", linewidth=0.6, zorder=1)

    ax.set_xlabel(f"PC1 ({var_exp[0]:.1f}%)", fontsize=9)
    ax.set_ylabel(f"PC2 ({var_exp[1]:.1f}%)", fontsize=9)
    ax.set_title(title, fontsize=10, pad=8)

    ax.legend(
        frameon=False,
        fontsize=8,
        markerscale=1.1,
        handletextpad=0.4,
        borderpad=0,
    )

    fig.tight_layout()
    return fig

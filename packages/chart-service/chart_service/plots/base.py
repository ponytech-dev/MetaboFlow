"""Base matplotlib configuration and shared utilities for publication-quality plots.

Follows Nature/NPG style: Arial/Helvetica fonts, no top/right spines,
NPG 10-color palette matching stats-worker/R/config.R.
"""

from __future__ import annotations

import io
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.figure import Figure

# Force non-interactive Agg backend — must be set before any other matplotlib import
matplotlib.use("Agg")

# ---------------------------------------------------------------------------
# Color palettes — mirror stats-worker/R/config.R
# ---------------------------------------------------------------------------

# NPG 10-color palette for group scatter / boxplot
NATURE_COLORS: list[str] = [
    "#E64B35",
    "#4DBBD5",
    "#00A087",
    "#3C5488",
    "#F39B7F",
    "#8491B4",
    "#91D1C2",
    "#DC0000",
    "#7E6148",
    "#B09C85",
]

# Volcano plot three-class colors (Down / Not-significant / Up)
VOLCANO_COLORS: dict[str, str] = {
    "Down": "#3C5488",
    "Not": "#D3D3D3",
    "Up": "#E64B35",
}

# Heatmap color ramp: blue-white-red
HEATMAP_CMAP = "bwr"  # matplotlib built-in approximation; customised in plot

# Pathway enrichment gradient: yellow → deep purple (viridis-like)
PATHWAY_CMAP_COLORS: list[str] = ["#FDE725", "#35B779", "#31688E", "#440154"]


# ---------------------------------------------------------------------------
# Global matplotlib defaults
# ---------------------------------------------------------------------------

def apply_nature_style() -> None:
    """Apply Nature-style rcParams globally."""
    plt.rcParams.update(
        {
            # Font
            "font.family": "sans-serif",
            "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
            "font.size": 9,
            "axes.titlesize": 10,
            "axes.labelsize": 9,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "legend.fontsize": 8,
            # Spines: remove top and right
            "axes.spines.top": False,
            "axes.spines.right": False,
            # Ticks
            "xtick.direction": "out",
            "ytick.direction": "out",
            "xtick.major.size": 3.5,
            "ytick.major.size": 3.5,
            "xtick.major.width": 0.8,
            "ytick.major.width": 0.8,
            # Lines
            "axes.linewidth": 0.8,
            "lines.linewidth": 1.2,
            # Grid: subtle
            "axes.grid": False,
            # Figure background
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            # DPI
            "figure.dpi": 100,
            # Savefig
            "savefig.dpi": 300,
            "savefig.bbox": "tight",
            "savefig.facecolor": "white",
        }
    )


# Apply once at import time
apply_nature_style()


# ---------------------------------------------------------------------------
# Save helpers
# ---------------------------------------------------------------------------

def save_plot(
    fig: Figure,
    path: str | Path,
    dpi: int = 300,
    fmt: str = "png",
) -> None:
    """Save a figure to disk.

    Args:
        fig: Matplotlib Figure to save.
        path: Output file path (extension overrides fmt if present).
        dpi: Resolution in dots per inch.
        fmt: File format ("png", "pdf", "svg").
    """
    fig.savefig(str(path), dpi=dpi, format=fmt, bbox_inches="tight")


def figure_to_bytes(fig: Figure, dpi: int = 300, fmt: str = "png") -> bytes:
    """Render a figure to an in-memory bytes buffer and return raw bytes.

    Args:
        fig: Matplotlib Figure to render.
        dpi: Resolution in dots per inch.
        fmt: Image format ("png", "pdf", "svg").

    Returns:
        Raw image bytes.
    """
    buf = io.BytesIO()
    fig.savefig(buf, dpi=dpi, format=fmt, bbox_inches="tight")
    buf.seek(0)
    data = buf.read()
    plt.close(fig)
    return data


def group_color_map(groups: list[str]) -> dict[str, str]:
    """Return a stable {group_label: hex_color} mapping using NATURE_COLORS.

    Args:
        groups: List of group labels (may contain duplicates).

    Returns:
        Dict mapping unique group labels to colors.
    """
    unique = list(dict.fromkeys(groups))  # preserve order, deduplicate
    return {
        g: NATURE_COLORS[i % len(NATURE_COLORS)] for i, g in enumerate(unique)
    }

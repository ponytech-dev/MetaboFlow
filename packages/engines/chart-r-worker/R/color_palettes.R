##############################################################################
##  chart-r-worker/R/color_palettes.R
##  MetaboFlow Color System — NPG-inspired, colorblind-safe
##
##  Mirrors packages/chart-service/chart_service/plots/base.py NATURE_COLORS
##  and stats-worker/R/config.R for cross-engine consistency.
##
##  References:
##    Python base.py NATURE_COLORS (10-color NPG palette)
##    Volcano: Down=#3C5488, Not=#D3D3D3, Up=#E64B35
##############################################################################

# ---------------------------------------------------------------------------
# Discrete palette — 10 colors, NPG-style, matches Python NATURE_COLORS
# ---------------------------------------------------------------------------

mf_discrete <- c(
  "#E64B35",  # red     — up-regulation, group A
  "#4DBBD5",  # cyan    — group B
  "#00A087",  # teal    — QC samples
  "#3C5488",  # blue    — down-regulation
  "#F39B7F",  # salmon
  "#8491B4",  # grey-blue
  "#91D1C2",  # light teal
  "#DC0000",  # deep red  (matches Python index 7)
  "#7E6148",  # brown
  "#B09C85"   # tan
)

# ---------------------------------------------------------------------------
# Semantic colors (named shortcuts)
# ---------------------------------------------------------------------------

mf_colors <- list(
  up              = "#E64B35",   # up-regulation
  down            = "#3C5488",   # down-regulation
  significant     = "#E64B35",
  not_significant = "#D3D3D3",   # matches Python VOLCANO_COLORS "Not"
  qc              = "#00A087",   # QC samples
  group_a         = "#E64B35",
  group_b         = "#4DBBD5"
)

# Volcano-specific three-class colors (matches Python VOLCANO_COLORS exactly)
mf_volcano_colors <- c(
  Down = "#3C5488",
  Not  = "#D3D3D3",
  Up   = "#E64B35"
)

# ---------------------------------------------------------------------------
# Diverging palette for heatmaps (blue-white-red)
# Matches Python HEATMAP_CMAP ("bwr")
# ---------------------------------------------------------------------------

mf_diverging <- function(n = 100) {
  colorRampPalette(c("#3C5488", "white", "#E64B35"))(n)
}

# ---------------------------------------------------------------------------
# Sequential palette for pathway enrichment (viridis-like, matches Python
# PATHWAY_CMAP_COLORS = ["#FDE725","#35B779","#31688E","#440154"])
# ---------------------------------------------------------------------------

mf_pathway <- function(n = 100) {
  colorRampPalette(c("#FDE725", "#35B779", "#31688E", "#440154"))(n)
}

# ---------------------------------------------------------------------------
# ggplot2 scale helpers
# ---------------------------------------------------------------------------

scale_color_metaboflow <- function(...) {
  ggplot2::scale_color_manual(values = mf_discrete, ...)
}

scale_fill_metaboflow <- function(...) {
  ggplot2::scale_fill_manual(values = mf_discrete, ...)
}

# Convenience: map a character vector of group labels to named color vector
group_color_map <- function(groups) {
  unique_groups <- unique(groups)
  colors <- mf_discrete[seq_along(unique_groups) %% length(mf_discrete) + 1]
  # Correct modulo for 1-based indexing
  idx <- ((seq_along(unique_groups) - 1) %% length(mf_discrete)) + 1
  setNames(mf_discrete[idx], unique_groups)
}

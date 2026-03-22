##############################################################################
##  templates/basic/hexbin_density.R
##  m/z vs RT hexbin density plot — feature space overview
##
##  md$var: feature metadata — needs mz and rt columns
##  params: bins (default 80)
##############################################################################

render_hexbin_density <- function(md, params) {
  library(ggplot2)

  var <- md$var

  if (is.null(var$mz) || is.null(var$rt)) {
    stop("hexbin_density requires md$var$mz and md$var$rt")
  }

  bins <- if (!is.null(params$bins)) params$bins else 80

  df <- data.frame(
    rt = var$rt,
    mz = var$mz
  )

  # Remove rows with NA
  df <- df[complete.cases(df), ]

  if (nrow(df) == 0) stop("hexbin_density: no valid mz/rt values")

  ggplot(df, aes(x = rt, y = mz)) +
    geom_hex(bins = bins) +
    scale_fill_viridis_c(option = "viridis", name = "Count") +
    labs(
      title = "Feature Density Map",
      x     = "Retention Time (s)",
      y     = "m/z"
    ) +
    theme_metaboflow()
}

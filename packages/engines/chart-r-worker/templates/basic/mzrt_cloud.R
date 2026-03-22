##############################################################################
##  templates/basic/mzrt_cloud.R
##  m/z vs RT scatter plot of all features (feature cloud)
##
##  md$var: feature metadata — needs mz and rt columns
##  md$X  : samples × features matrix — used to derive max intensity per feature
##  params: (none specific)
##############################################################################

render_mzrt_cloud <- function(md, params) {
  library(ggplot2)

  var <- md$var

  if (is.null(var$mz) || is.null(var$rt)) {
    stop("mzrt_cloud requires md$var$mz and md$var$rt")
  }

  # Max intensity per feature (column of X)
  max_int <- apply(md$X, 2, function(x) max(x, na.rm = TRUE))
  max_int[!is.finite(max_int)] <- NA

  df <- data.frame(
    rt      = var$rt,
    mz      = var$mz,
    max_int = max_int
  )

  # Significance coloring if available
  if (!is.null(var$significant)) {
    df$sig <- as.character(var$significant)
    df$sig[is.na(df$sig)] <- "FALSE"

    color_map <- c("TRUE" = mf_colors$up, "FALSE" = mf_colors$not_significant)

    p <- ggplot(df, aes(x = rt, y = mz, size = log10(pmax(max_int, 1, na.rm = TRUE)),
                         color = sig)) +
      geom_point(alpha = 0.5) +
      scale_color_manual(values = color_map,
                         labels = c("TRUE" = "Significant", "FALSE" = "Not significant"),
                         name   = "Status")
  } else {
    p <- ggplot(df, aes(x = rt, y = mz, size = log10(pmax(max_int, 1, na.rm = TRUE)))) +
      geom_point(alpha = 0.5, color = mf_discrete[2])
  }

  p +
    scale_size_continuous(name = "log10(max intensity)", range = c(0.5, 4)) +
    labs(
      title = "Feature Cloud",
      x     = "Retention Time (s)",
      y     = "m/z"
    ) +
    theme_metaboflow()
}

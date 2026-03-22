##############################################################################
##  templates/basic/qc_intensity.R
##  Per-sample total intensity boxplot grouped by sample_type — QC assessment
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with columns: sample_id, sample_type
##  params: (none specific)
##############################################################################

render_qc_intensity <- function(md, params) {
  library(ggplot2)

  X   <- md$X
  obs <- md$obs

  # Total intensity per sample
  total_int <- rowSums(X, na.rm = TRUE)

  # Determine sample_type column (fallback to group if missing)
  if (!is.null(obs$sample_type) && !all(is.na(obs$sample_type))) {
    sample_type <- obs$sample_type
  } else {
    warning("qc_intensity: md$obs$sample_type not found — using md$obs$group")
    sample_type <- obs$group
  }

  df <- data.frame(
    sample_id   = obs$sample_id,
    total_int   = total_int,
    sample_type = as.character(sample_type)
  )

  # Build fill color map — highlight QC with mf_colors$qc
  types <- unique(df$sample_type)
  fill_colors <- setNames(
    mf_discrete[seq_along(types) %% length(mf_discrete) + 1],
    types
  )
  # Override QC color if present
  qc_keys <- types[grepl("qc|QC|Qc", types)]
  for (k in qc_keys) fill_colors[k] <- mf_colors$qc

  # Global median line value
  median_val <- median(df$total_int, na.rm = TRUE)

  ggplot(df, aes(x = sample_type, y = total_int, fill = sample_type)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7, width = 0.5) +
    geom_jitter(width = 0.15, size = 1.5, alpha = 0.6,
                aes(color = sample_type)) +
    geom_hline(yintercept = median_val, linetype = "dashed",
               color = "grey40", linewidth = 0.6) +
    annotate("text", x = Inf, y = median_val, hjust = 1.1, vjust = -0.4,
             label = sprintf("Median: %.2e", median_val),
             size = 3, color = "grey40") +
    scale_fill_manual(values = fill_colors) +
    scale_color_manual(values = fill_colors) +
    labs(
      title = "Per-Sample Total Intensity",
      x     = "Sample Type",
      y     = "Total Intensity",
      fill  = "Sample Type",
      color = "Sample Type"
    ) +
    theme_metaboflow() +
    theme(legend.position = "none")
}

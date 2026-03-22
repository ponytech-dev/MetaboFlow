##############################################################################
##  templates/basic/rsd_distribution.R
##  RSD% (CV) distribution histogram across QC samples
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with column: sample_type
##  params: rsd_thresh1 (default 20), rsd_thresh2 (default 30), bins (default 50)
##############################################################################

render_rsd_distribution <- function(md, params) {
  library(ggplot2)

  X   <- md$X
  obs <- md$obs

  rsd_thresh1 <- if (!is.null(params$rsd_thresh1)) params$rsd_thresh1 else 20
  rsd_thresh2 <- if (!is.null(params$rsd_thresh2)) params$rsd_thresh2 else 30
  bins        <- if (!is.null(params$bins))        params$bins        else 50

  # Identify QC samples
  if (!is.null(obs$sample_type)) {
    qc_mask <- grepl("qc|QC|Qc", obs$sample_type)
  } else {
    qc_mask <- rep(FALSE, nrow(X))
  }

  if (sum(qc_mask) >= 3) {
    X_qc   <- X[qc_mask, , drop = FALSE]
    source_label <- "QC Samples"
  } else {
    warning("rsd_distribution: fewer than 3 QC samples — using all samples for RSD")
    X_qc   <- X
    source_label <- "All Samples"
  }

  # Calculate CV% per feature
  feat_mean <- apply(X_qc, 2, mean, na.rm = TRUE)
  feat_sd   <- apply(X_qc, 2, sd,   na.rm = TRUE)
  rsd       <- (feat_sd / abs(feat_mean)) * 100

  # Remove Inf and NaN
  rsd <- rsd[is.finite(rsd) & feat_mean > 0]

  if (length(rsd) == 0) stop("rsd_distribution: no valid RSD values computed")

  pct_below1 <- mean(rsd <= rsd_thresh1) * 100
  pct_below2 <- mean(rsd <= rsd_thresh2) * 100

  df <- data.frame(rsd = rsd)

  ggplot(df, aes(x = rsd)) +
    geom_histogram(bins = bins, fill = mf_discrete[2], color = "white",
                   alpha = 0.85) +
    geom_vline(xintercept = rsd_thresh1, linetype = "dashed",
               color = mf_colors$up, linewidth = 0.8) +
    geom_vline(xintercept = rsd_thresh2, linetype = "dashed",
               color = mf_colors$down, linewidth = 0.8) +
    annotate("text",
             x = rsd_thresh1, y = Inf, vjust = 1.5, hjust = -0.1,
             label = sprintf("<%g%%: %.1f%% features", rsd_thresh1, pct_below1),
             color = mf_colors$up, size = 3.2, fontface = "bold") +
    annotate("text",
             x = rsd_thresh2, y = Inf, vjust = 3.5, hjust = -0.1,
             label = sprintf("<%g%%: %.1f%% features", rsd_thresh2, pct_below2),
             color = mf_colors$down, size = 3.2, fontface = "bold") +
    labs(
      title    = "RSD% Distribution",
      subtitle = sprintf("Source: %s (n = %d features)", source_label, length(rsd)),
      x        = "RSD (%)",
      y        = "Number of Features"
    ) +
    theme_metaboflow()
}

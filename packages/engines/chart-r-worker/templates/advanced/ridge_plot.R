##############################################################################
##  templates/advanced/ridge_plot.R
##  A15 — Ridge / joy plot of intensity distributions
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group
##  md$var: feature_id, optional compound_name, pvalue
##  params: top_n (default 15), log_transform (default TRUE)
##          feature_ids (optional: override auto-selection)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_ridge_plot <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("ggridges", quietly = TRUE)) {
    return(.placeholder_plot(
      "ggridges package required\nInstall: install.packages('ggridges')"
    ))
  }
  library(ggridges)

  X   <- md$X
  obs <- md$obs
  var <- md$var

  top_n         <- if (!is.null(params$top_n))         params$top_n         else 15
  log_transform <- if (!is.null(params$log_transform)) params$log_transform else TRUE

  # Feature selection
  feature_ids <- params$feature_ids
  if (is.null(feature_ids)) {
    if (!is.null(var$pvalue) && any(!is.na(var$pvalue))) {
      ord         <- order(var$pvalue, na.last = TRUE)
      feature_ids <- colnames(X)[ord[seq_len(min(top_n, ncol(X)))]]
    } else {
      row_vars    <- apply(X, 2, var, na.rm = TRUE)
      feature_ids <- colnames(X)[order(row_vars, decreasing = TRUE)[seq_len(min(top_n, ncol(X)))]]
    }
  }
  feature_ids <- intersect(feature_ids, colnames(X))
  if (length(feature_ids) == 0) {
    return(.placeholder_plot("No features found"))
  }

  X_sub <- X[, feature_ids, drop = FALSE]
  if (log_transform) {
    X_sub <- log2(X_sub + 1)
  }

  # Build long format
  long_df <- data.frame(
    intensity  = as.vector(X_sub),
    feature_id = rep(feature_ids, each = nrow(X_sub)),
    group      = rep(obs$group, times = length(feature_ids)),
    stringsAsFactors = FALSE
  )
  long_df <- long_df[!is.na(long_df$intensity), ]

  # Feature labels
  if (!is.null(var$compound_name)) {
    name_map <- setNames(var$compound_name, var$feature_id)
    long_df$feat_label <- ifelse(
      is.na(name_map[long_df$feature_id]),
      long_df$feature_id,
      name_map[long_df$feature_id]
    )
  } else {
    long_df$feat_label <- long_df$feature_id
  }

  # Order features by median intensity (ascending for ridge stacking)
  feat_medians <- tapply(long_df$intensity, long_df$feat_label,
                          median, na.rm = TRUE)
  feat_order   <- names(sort(feat_medians))
  long_df$feat_label <- factor(long_df$feat_label, levels = feat_order)

  n_groups   <- length(unique(obs$group))
  group_pal  <- group_color_map(obs$group)

  ggplot(long_df, aes(x = intensity, y = feat_label, fill = group, color = group)) +
    geom_density_ridges(alpha = 0.55, scale = 1.2, rel_min_height = 0.01,
                         quantile_lines = TRUE, quantiles = 2) +
    scale_fill_manual(values = group_pal, name = "Group") +
    scale_color_manual(values = group_pal, guide = "none") +
    labs(
      title    = sprintf("Ridge Plot — Top %d Features", length(feature_ids)),
      subtitle = if (log_transform) "log2(intensity + 1)" else "Raw intensity",
      x        = if (log_transform) "log2(Intensity + 1)" else "Intensity",
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(
      axis.text.y     = element_text(size = 7),
      legend.position = "right"
    )
}

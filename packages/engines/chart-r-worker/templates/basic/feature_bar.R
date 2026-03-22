##############################################################################
##  templates/basic/feature_bar.R
##  Bar chart of top-N key metabolites across groups (mean ± SE + sig stars)
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with column: group
##  md$var: feature metadata — needs pvalue for selection
##  params: top_n (default 8)
##############################################################################

render_feature_bar <- function(md, params) {
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  top_n_val <- if (!is.null(params$top_n)) params$top_n else 8

  X   <- md$X
  obs <- md$obs
  var <- md$var

  # Select top features
  if (!is.null(var$pvalue) && !all(is.na(var$pvalue))) {
    ord <- order(var$pvalue, na.last = TRUE)
  } else {
    warning("feature_bar: md$var$pvalue not found — using top variance features")
    row_vars <- apply(X, 2, var, na.rm = TRUE)
    ord <- order(row_vars, decreasing = TRUE)
  }

  n_sel   <- min(top_n_val, ncol(X))
  sel_idx <- ord[seq_len(n_sel)]
  var_sub <- var[sel_idx, , drop = FALSE]

  feat_labels <- if (!is.null(var_sub$compound_name) && any(!is.na(var_sub$compound_name))) {
    ifelse(is.na(var_sub$compound_name), var_sub$feature_id, var_sub$compound_name)
  } else {
    var_sub$feature_id
  }
  names(feat_labels) <- var_sub$feature_id

  # Build long data frame
  df <- as.data.frame(X[, sel_idx, drop = FALSE])
  colnames(df) <- var_sub$feature_id
  df$group <- obs$group

  df_long <- tidyr::pivot_longer(df, cols = -group,
                                  names_to  = "feature_id",
                                  values_to = "intensity")
  df_long$feature_label <- feat_labels[df_long$feature_id]
  df_long$feature_label <- factor(df_long$feature_label,
                                   levels = feat_labels)

  # Summary: mean ± SE per group × feature
  df_summary <- df_long |>
    dplyr::group_by(feature_label, group) |>
    dplyr::summarise(
      mean_int = mean(intensity, na.rm = TRUE),
      se_int   = sd(intensity, na.rm = TRUE) / sqrt(dplyr::n()),
      .groups  = "drop"
    )

  # Compute significance stars per feature (Wilcoxon)
  groups <- unique(obs$group)
  if (length(groups) == 2) {
    pvals <- sapply(levels(df_long$feature_label), function(fl) {
      sub <- df_long[df_long$feature_label == fl, ]
      g1 <- sub$intensity[sub$group == groups[1]]
      g2 <- sub$intensity[sub$group == groups[2]]
      tryCatch(wilcox.test(g1, g2)$p.value, error = function(e) NA)
    })
    p_to_stars <- function(p) {
      if (is.na(p)) "ns" else if (p < 0.001) "***" else if (p < 0.01) "**" else if (p < 0.05) "*" else "ns"
    }
    anno_df <- data.frame(
      feature_label = factor(names(pvals), levels = levels(df_long$feature_label)),
      label = sapply(pvals, p_to_stars),
      stringsAsFactors = FALSE
    )
    y_pos <- df_summary |> group_by(feature_label) |> summarise(y = max(mean_int + se_int, na.rm = TRUE) * 1.15, .groups = "drop")
    anno_df <- merge(anno_df, y_pos, by = "feature_label")
    anno_df$x <- 1.5
  } else {
    anno_df <- NULL
  }

  p <- ggplot(df_summary, aes(x = group, y = mean_int, fill = group)) +
    geom_col(width = 0.6, alpha = 0.85) +
    geom_errorbar(aes(ymin = mean_int - se_int, ymax = mean_int + se_int),
                  width = 0.2, linewidth = 0.5) +
    facet_wrap(~feature_label, scales = "free_y", ncol = 4) +
    scale_fill_metaboflow() +
    labs(
      title = sprintf("Top %d Features — Mean Intensity per Group", n_sel),
      x     = NULL,
      y     = "Mean Intensity",
      fill  = "Group"
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x  = element_text(angle = 30, hjust = 1),
      legend.position = "none"
    )

  if (!is.null(anno_df)) {
    p <- p + geom_text(data = anno_df, aes(x = x, y = y, label = label),
                       inherit.aes = FALSE, size = 4, color = "black")
  }
  p
}

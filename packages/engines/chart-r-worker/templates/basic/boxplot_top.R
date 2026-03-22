##############################################################################
##  templates/basic/boxplot_top.R
##  Faceted boxplot of top-N significant features across groups
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with column: group
##  md$var: feature metadata — needs pvalue for feature selection
##  params: top_n (default 9)
##############################################################################

render_boxplot_top <- function(md, params) {
  library(ggplot2)
  library(ggpubr)
  library(dplyr)
  library(tidyr)

  top_n <- if (!is.null(params$top_n)) params$top_n else 9

  X   <- md$X
  obs <- md$obs
  var <- md$var

  # Select top features
  if (!is.null(var$pvalue) && !all(is.na(var$pvalue))) {
    ord <- order(var$pvalue, na.last = TRUE)
  } else {
    warning("boxplot_top: md$var$pvalue not found — using top variance features")
    row_vars <- apply(X, 2, var, na.rm = TRUE)
    ord <- order(row_vars, decreasing = TRUE)
  }

  n_sel   <- min(top_n, ncol(X))
  sel_idx <- ord[seq_len(n_sel)]

  var_sub <- var[sel_idx, , drop = FALSE]

  # Build feature label (prefer compound_name)
  feat_labels <- if (!is.null(var_sub$compound_name) && any(!is.na(var_sub$compound_name))) {
    ifelse(is.na(var_sub$compound_name), var_sub$feature_id, var_sub$compound_name)
  } else {
    var_sub$feature_id
  }
  names(feat_labels) <- var_sub$feature_id

  # Long-format data frame
  df <- as.data.frame(X[, sel_idx, drop = FALSE])
  colnames(df) <- var_sub$feature_id
  df$group <- obs$group
  df$sample_id <- obs$sample_id

  df_long <- tidyr::pivot_longer(
    df,
    cols      = -c(group, sample_id),
    names_to  = "feature_id",
    values_to = "intensity"
  )
  df_long$feature_label <- feat_labels[df_long$feature_id]

  groups <- unique(obs$group)
  comparisons <- if (length(groups) == 2) {
    list(as.character(groups))
  } else {
    # All pairwise combinations
    combn(as.character(groups), 2, simplify = FALSE)
  }

  ggplot(df_long, aes(x = group, y = intensity, fill = group)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7, width = 0.6) +
    geom_jitter(aes(color = group), width = 0.15, size = 1, alpha = 0.6) +
    ggpubr::stat_compare_means(
      comparisons = comparisons,
      method      = "wilcox.test",
      label       = "p.signif",
      size        = 3
    ) +
    facet_wrap(~feature_label, scales = "free_y", ncol = 3) +
    scale_fill_metaboflow() +
    scale_color_metaboflow() +
    labs(
      title = sprintf("Top %d Significant Features", n_sel),
      x     = NULL,
      y     = "Intensity",
      fill  = "Group",
      color = "Group"
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x  = element_text(angle = 30, hjust = 1),
      legend.position = "none"
    )
}

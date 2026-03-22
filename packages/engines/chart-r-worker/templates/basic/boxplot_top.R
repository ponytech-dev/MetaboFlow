##############################################################################
##  templates/basic/boxplot_top.R
##  Faceted boxplot of top-N significant features across groups
##
##  md$X  : samples x features matrix
##  md$obs: sample metadata with column: group
##  md$var: feature metadata — needs pvalue for feature selection
##  params: top_n (default 9)
##############################################################################

render_boxplot_top <- function(md, params) {
  library(ggplot2)
  library(dplyr)
  library(tidyr)

  top_n_val <- if (!is.null(params$top_n)) params$top_n else 9

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

  n_sel   <- min(top_n_val, ncol(X))
  sel_idx <- ord[seq_len(n_sel)]
  var_sub <- var[sel_idx, , drop = FALSE]

  # Build feature label
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

  # Compute Wilcoxon p-values per feature for annotation
  groups <- unique(obs$group)
  if (length(groups) == 2) {
    pvals <- sapply(unique(df_long$feature_label), function(fl) {
      sub <- df_long[df_long$feature_label == fl, ]
      g1 <- sub$intensity[sub$group == groups[1]]
      g2 <- sub$intensity[sub$group == groups[2]]
      tryCatch(wilcox.test(g1, g2)$p.value, error = function(e) NA)
    })
    # Map p-value to stars
    p_to_stars <- function(p) {
      if (is.na(p)) return("ns")
      if (p < 0.001) return("***")
      if (p < 0.01) return("**")
      if (p < 0.05) return("*")
      return("ns")
    }
    star_labels <- sapply(pvals, p_to_stars)

    # Create annotation data frame
    anno_df <- data.frame(
      feature_label = names(star_labels),
      label = as.character(star_labels),
      stringsAsFactors = FALSE
    )
  } else {
    anno_df <- NULL
  }

  p <- ggplot(df_long, aes(x = group, y = intensity, fill = group)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7, width = 0.6) +
    geom_jitter(aes(color = group), width = 0.15, size = 1.5, alpha = 0.6) +
    facet_wrap(~feature_label, scales = "free_y", ncol = 3) +
    scale_fill_metaboflow() +
    scale_color_metaboflow() +
    labs(
      title = sprintf("Top %d Features", n_sel),
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

  # Add significance stars as text annotation at top of each facet
  if (!is.null(anno_df)) {
    # Calculate y position per facet (max intensity + 10%)
    y_pos <- df_long %>%
      group_by(feature_label) %>%
      summarise(ymax = max(intensity, na.rm = TRUE), .groups = "drop") %>%
      mutate(y = ymax * 1.1)
    anno_df <- merge(anno_df, y_pos, by = "feature_label")
    # x position: midpoint between groups
    anno_df$x <- 1.5

    p <- p + geom_text(
      data = anno_df,
      aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      size = 4, color = "black"
    )
  }

  p
}

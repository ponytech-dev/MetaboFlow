##############################################################################
##  templates/advanced/multi_contrast_bubble.R
##  A08 — Multi-contrast bubble heatmap matrix
##
##  md$uns$contrasts: named list of data.frames, each with:
##    feature_id, logFC, pvalue (or adj_pvalue)
##  md$var: feature_id, optional compound_name
##  params: fc_cut (default 1), p_cut (default 0.05), top_n (default 30)
##          p_col: "pvalue" | "adj_pvalue" (default "pvalue")
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_multi_contrast_bubble <- function(md, params) {
  library(ggplot2)

  contrasts <- md$uns$contrasts
  if (is.null(contrasts) || length(contrasts) == 0) {
    return(.placeholder_plot(
      "multi_contrast_bubble requires md$uns$contrasts\n(named list of contrast data.frames)"
    ))
  }

  fc_cut <- if (!is.null(params$fc_cut)) params$fc_cut else 1
  p_cut  <- if (!is.null(params$p_cut))  params$p_cut  else 0.05
  top_n  <- if (!is.null(params$top_n))  params$top_n  else 30
  p_col  <- if (!is.null(params$p_col))  params$p_col  else "pvalue"

  var <- md$var

  # Build long data.frame from all contrasts
  long_df <- do.call(rbind, lapply(names(contrasts), function(contrast_name) {
    ct <- contrasts[[contrast_name]]
    pv <- if (!is.null(ct[[p_col]])) ct[[p_col]] else ct$pvalue
    data.frame(
      feature_id    = ct$feature_id,
      contrast      = contrast_name,
      logFC         = ct$logFC,
      pvalue        = pv,
      stringsAsFactors = FALSE
    )
  }))

  # Add compound name
  if (!is.null(var$compound_name)) {
    name_map <- setNames(var$compound_name, var$feature_id)
    long_df$label <- ifelse(
      is.na(name_map[long_df$feature_id]) | is.null(name_map[long_df$feature_id]),
      long_df$feature_id,
      name_map[long_df$feature_id]
    )
  } else {
    long_df$label <- long_df$feature_id
  }

  # Select top_n features that are significant in at least one contrast
  sig_features <- unique(long_df$feature_id[
    abs(long_df$logFC) >= fc_cut & long_df$pvalue <= p_cut
  ])

  if (length(sig_features) == 0) {
    return(.placeholder_plot(
      sprintf("No features significant at FC≥%g, p≤%g across contrasts", fc_cut, p_cut)
    ))
  }

  # Rank by number of significant contrasts + max |logFC|
  rank_df <- aggregate(
    cbind(n_sig = abs(logFC) >= fc_cut & pvalue <= p_cut,
          max_fc = abs(logFC)) ~ feature_id,
    data = long_df[long_df$feature_id %in% sig_features, ],
    FUN = function(x) if (is.logical(x)) sum(x) else max(x)
  )
  top_features <- rank_df$feature_id[order(rank_df$n_sig, rank_df$max_fc, decreasing = TRUE)]
  top_features <- head(top_features, top_n)

  plot_df <- long_df[long_df$feature_id %in% top_features, ]
  plot_df$neg_log10_p  <- -log10(pmax(plot_df$pvalue, 1e-300))
  plot_df$sig          <- abs(plot_df$logFC) >= fc_cut & plot_df$pvalue <= p_cut
  plot_df$bubble_size  <- ifelse(plot_df$sig, plot_df$neg_log10_p, 0.5)

  # Consistent label ordering
  label_map       <- unique(plot_df[, c("feature_id", "label")])
  feat_order      <- top_features
  label_order     <- label_map$label[match(feat_order, label_map$feature_id)]
  plot_df$label_f <- factor(plot_df$label, levels = rev(label_order))

  ggplot(plot_df, aes(x = contrast, y = label_f)) +
    geom_point(aes(size = bubble_size, fill = logFC), shape = 21,
               color = "white", stroke = 0.3, alpha = 0.9) +
    scale_size_continuous(range = c(1, 8), name = "-log10(p)") +
    scale_fill_gradient2(
      low = mf_colors$down, mid = "white", high = mf_colors$up,
      midpoint = 0, name = "log2FC"
    ) +
    labs(
      title = "Multi-Contrast Bubble Heatmap",
      subtitle = sprintf("Significant features (|FC|≥%g, p≤%g)", fc_cut, p_cut),
      x = "Contrast", y = NULL
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x  = element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y  = element_text(size = 7),
      legend.position = "right"
    )
}

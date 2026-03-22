##############################################################################
##  templates/advanced/forest_plot.R
##  A10 — Forest plot with CI and effect sizes
##
##  md$var: feature_id, logFC, CI_low, CI_high, pvalue, optional compound_name,
##          cf_superclass
##  params: top_n (default 25), p_cut (default 0.05), fc_cut (default 1)
##          sort_by: "logFC" | "pvalue" | "superclass" (default "logFC")
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_forest_plot <- function(md, params) {
  library(ggplot2)

  var <- md$var
  if (is.null(var$logFC)) {
    return(.placeholder_plot("forest_plot requires md$var$logFC"))
  }

  # If CI absent, approximate from pvalue (normal approx)
  if (is.null(var$CI_low) || all(is.na(var$CI_low))) {
    warning("forest_plot: CI_low/CI_high absent — approximating 95% CI from SE (logFC/1.96)")
    if (!is.null(var$pvalue)) {
      se_approx    <- abs(var$logFC) / (qnorm(1 - var$pvalue / 2) + 1e-8)
      var$CI_low   <- var$logFC - 1.96 * se_approx
      var$CI_high  <- var$logFC + 1.96 * se_approx
    } else {
      return(.placeholder_plot("forest_plot: need md$var$CI_low/CI_high or md$var$pvalue"))
    }
  }

  top_n   <- if (!is.null(params$top_n))   params$top_n   else 25
  p_cut   <- if (!is.null(params$p_cut))   params$p_cut   else 0.05
  fc_cut  <- if (!is.null(params$fc_cut))  params$fc_cut  else 1
  sort_by <- if (!is.null(params$sort_by)) params$sort_by else "logFC"

  df <- var[!is.na(var$logFC), ]

  # Sort and subset
  df <- switch(sort_by,
    pvalue    = df[order(df$pvalue, na.last = TRUE), ],
    superclass = if (!is.null(df$cf_superclass)) df[order(df$cf_superclass), ] else
                 df[order(df$pvalue, na.last = TRUE), ],
    df[order(abs(df$logFC), decreasing = TRUE), ]  # default: logFC
  )
  df <- head(df, top_n)

  # Labels
  df$label <- if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    ifelse(is.na(df$compound_name), df$feature_id, df$compound_name)
  } else { df$feature_id }

  # Significance marker
  df$sig <- !is.na(df$pvalue) & df$pvalue <= p_cut & abs(df$logFC) >= fc_cut
  df$color <- ifelse(df$logFC > 0, mf_colors$up, mf_colors$down)
  df$color[!df$sig] <- mf_colors$not_significant

  df$label_f <- factor(df$label, levels = rev(df$label))

  # Superclass grouping facet (optional)
  use_facet <- !is.null(df$cf_superclass) && sort_by == "superclass" &&
               any(!is.na(df$cf_superclass))
  if (use_facet) {
    df$facet_group <- ifelse(is.na(df$cf_superclass), "Unknown", df$cf_superclass)
  }

  p <- ggplot(df, aes(y = label_f, x = logFC, xmin = CI_low, xmax = CI_high, color = sig)) +
    geom_vline(xintercept = 0, color = "grey40", linewidth = 0.6) +
    geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed",
               color = "grey60", linewidth = 0.4) +
    geom_errorbarh(height = 0.3, linewidth = 0.6) +
    geom_point(aes(size = -log10(pmax(pvalue, 1e-300))), shape = 18) +
    scale_color_manual(values = c("FALSE" = mf_colors$not_significant, "TRUE" = mf_colors$up),
                       labels = c("FALSE" = "NS", "TRUE" = "Significant"), name = NULL) +
    scale_size_continuous(range = c(2, 6), name = "-log10(p)") +
    labs(
      title    = "Forest Plot — Effect Sizes with 95% CI",
      subtitle = sprintf("|FC| cut: %g  |  p cut: %g", fc_cut, p_cut),
      x        = "log2 Fold Change (95% CI)",
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(axis.text.y = element_text(size = 7), legend.position = "right")

  if (use_facet) {
    p <- p + facet_grid(facet_group ~ ., scales = "free_y", space = "free_y") +
      theme(strip.text.y = element_text(size = 7, angle = 0))
  }

  p
}

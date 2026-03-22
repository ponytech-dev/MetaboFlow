##############################################################################
##  templates/advanced/scatter_marginal.R
##  A09 — Scatter with marginal density distributions
##
##  Compares logFC of two contrasts per feature, with marginal density plots
##
##  md$uns$contrasts: named list with at least 2 contrast data.frames
##    each with: feature_id, logFC, optional significant
##  md$var: feature_id, optional compound_name
##  params: contrast_x, contrast_y (default: first two contrast names)
##          label_sig (default TRUE), fc_cut (default 1)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_scatter_marginal <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  contrasts <- md$uns$contrasts
  if (is.null(contrasts) || length(contrasts) < 2) {
    return(.placeholder_plot(
      "scatter_marginal requires md$uns$contrasts with at least 2 contrasts"
    ))
  }

  ct_names <- names(contrasts)
  cx_name  <- if (!is.null(params$contrast_x)) params$contrast_x else ct_names[1]
  cy_name  <- if (!is.null(params$contrast_y)) params$contrast_y else ct_names[2]
  fc_cut   <- if (!is.null(params$fc_cut))     params$fc_cut     else 1

  cx <- contrasts[[cx_name]]
  cy <- contrasts[[cy_name]]

  if (is.null(cx) || is.null(cy)) {
    return(.placeholder_plot(
      sprintf("Contrast '%s' or '%s' not found in md$uns$contrasts", cx_name, cy_name)
    ))
  }

  # Merge on feature_id
  merged <- merge(
    cx[, c("feature_id", "logFC")],
    cy[, c("feature_id", "logFC")],
    by = "feature_id", suffixes = c("_x", "_y")
  )

  if (nrow(merged) == 0) {
    return(.placeholder_plot("No shared feature_ids between the two contrasts"))
  }

  # Quadrant classification
  merged$pattern <- dplyr::case_when(
    merged$logFC_x >= fc_cut  & merged$logFC_y >= fc_cut  ~ "Both Up",
    merged$logFC_x <= -fc_cut & merged$logFC_y <= -fc_cut ~ "Both Down",
    merged$logFC_x >= fc_cut  & merged$logFC_y <= -fc_cut ~ "Discordant",
    merged$logFC_x <= -fc_cut & merged$logFC_y >= fc_cut  ~ "Discordant",
    TRUE                                                   ~ "Neutral"
  )

  pat_colors <- c(
    "Both Up"    = mf_colors$up,
    "Both Down"  = mf_colors$down,
    "Discordant" = "#F39B7F",
    "Neutral"    = mf_colors$not_significant
  )

  # Main scatter
  p_main <- ggplot(merged, aes(x = logFC_x, y = logFC_y, color = pattern)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.4) +
    geom_vline(xintercept = 0, color = "grey60", linewidth = 0.4) +
    geom_hline(yintercept = c(-fc_cut, fc_cut), linetype = "dashed",
               color = "grey70", linewidth = 0.4) +
    geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed",
               color = "grey70", linewidth = 0.4) +
    geom_point(size = 1.8, alpha = 0.75) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                color = "grey30", fill = "grey80", linewidth = 0.8) +
    scale_color_manual(values = pat_colors, name = "Pattern") +
    labs(x = sprintf("log2FC: %s", cx_name), y = sprintf("log2FC: %s", cy_name)) +
    theme_metaboflow() +
    theme(legend.position = "none")

  # Top marginal: distribution for cx
  p_top <- ggplot(merged, aes(x = logFC_x, fill = pattern)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = pat_colors) +
    theme_void() +
    theme(legend.position = "none")

  # Right marginal: distribution for cy
  p_right <- ggplot(merged, aes(x = logFC_y, fill = pattern)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = pat_colors) +
    coord_flip() +
    theme_void() +
    theme(legend.position = "none")

  # Correlation stat
  r_val <- round(cor(merged$logFC_x, merged$logFC_y, use = "complete.obs"), 3)

  (p_top + plot_spacer() + p_main + p_right) +
    plot_layout(ncol = 2, nrow = 2, widths = c(4, 1), heights = c(1, 4)) +
    plot_annotation(
      title   = sprintf("Scatter: %s vs %s", cx_name, cy_name),
      caption = sprintf("Pearson r = %s  (n=%d features)", r_val, nrow(merged))
    )
}

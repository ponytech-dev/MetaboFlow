##############################################################################
##  templates/advanced/volcano_pathway_dual.R
##  A26 — Volcano + pathway enrichment dual panel
##
##  md$var: feature_id, logFC, pvalue, optional compound_name
##  md$uns$pathway_results: data.frame with pathway_name, p_value, ratio, count,
##    optional bg_count (for enrichment ratio)
##  params: fc_cut (default 1), p_cut (default 0.05), top_pathways (default 15)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_volcano_pathway_dual <- function(md, params) {
  library(ggplot2)
  library(ggrepel)
  library(patchwork)

  fc_cut       <- if (!is.null(params$fc_cut))        params$fc_cut        else 1
  p_cut        <- if (!is.null(params$p_cut))         params$p_cut         else 0.05
  top_pathways <- if (!is.null(params$top_pathways))  params$top_pathways  else 15

  var <- md$var
  if (is.null(var$logFC) || is.null(var$pvalue)) {
    return(.placeholder_plot("volcano_pathway_dual requires md$var$logFC and md$var$pvalue"))
  }

  # ---- Left: Volcano ----
  df <- var
  df$neg_log10_p <- -log10(pmax(df$pvalue, 1e-300))
  df$regulation  <- dplyr::case_when(
    df$logFC >= fc_cut  & df$pvalue <= p_cut ~ "Up",
    df$logFC <= -fc_cut & df$pvalue <= p_cut ~ "Down",
    TRUE                                     ~ "Not"
  )
  df$label <- ""
  sig_mask  <- df$regulation != "Not"
  if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    df$label[sig_mask] <- ifelse(is.na(df$compound_name[sig_mask]),
                                  df$feature_id[sig_mask],
                                  df$compound_name[sig_mask])
  } else {
    df$label[sig_mask] <- df$feature_id[sig_mask]
  }

  n_up   <- sum(df$regulation == "Up")
  n_down <- sum(df$regulation == "Down")

  p_volcano <- ggplot(df, aes(x = logFC, y = neg_log10_p, color = regulation)) +
    geom_hline(yintercept = -log10(p_cut), linetype = "dashed", color = "grey60", linewidth = 0.5) +
    geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed", color = "grey60", linewidth = 0.5) +
    geom_point(size = 1.8, alpha = 0.75) +
    geom_text_repel(aes(label = label), size = 2.5, max.overlaps = 15,
                    segment.color = "grey50", segment.size = 0.3) +
    scale_color_manual(values = mf_volcano_colors, name = NULL) +
    annotate("text", x = Inf, y = Inf, hjust = 1.1, vjust = 1.5,
             label = sprintf("↑%d  ↓%d", n_up, n_down), size = 3.5, color = "grey30") +
    labs(title = "Differential Metabolites", x = "log2FC", y = "-log10(p)") +
    theme_metaboflow() +
    theme(legend.position = "none")

  # ---- Right: Pathway enrichment ----
  pw_res <- md$uns$pathway_results

  if (is.null(pw_res) || nrow(pw_res) == 0) {
    p_pathway <- .placeholder_plot(
      "Pathway enrichment not available\nProvide md$uns$pathway_results"
    )
  } else {
    pw_res <- pw_res[!is.na(pw_res$p_value), ]
    pw_res <- pw_res[order(pw_res$p_value), ]
    pw_res <- head(pw_res, top_pathways)

    pw_res$neg_log10_p    <- -log10(pmax(pw_res$p_value, 1e-300))
    pw_res$pathway_name_f <- factor(pw_res$pathway_name,
                                     levels = rev(pw_res$pathway_name))

    # Bubble: x = enrichment ratio or count, y = pathway, size = count, color = -log10p
    x_var <- if (!is.null(pw_res$ratio)) "ratio" else if (!is.null(pw_res$count)) "count" else NULL

    if (is.null(x_var)) {
      p_pathway <- .placeholder_plot("pathway_results needs 'ratio' or 'count' column")
    } else {
      p_pathway <- ggplot(pw_res,
                           aes(x = .data[[x_var]], y = pathway_name_f,
                               size = if (!is.null(pw_res$count)) count else 1,
                               color = neg_log10_p)) +
        geom_point(alpha = 0.9) +
        scale_color_gradientn(colors = mf_pathway(100), name = "-log10(p)") +
        scale_size_continuous(range = c(3, 10), name = "Hits") +
        labs(
          title = "Pathway Enrichment",
          x     = if (x_var == "ratio") "Enrichment Ratio" else "Hit Count",
          y     = NULL
        ) +
        theme_metaboflow() +
        theme(axis.text.y = element_text(size = 7), legend.position = "right")
    }
  }

  (p_volcano | p_pathway) +
    plot_annotation(title = "Differential Metabolites + Pathway Enrichment") +
    plot_layout(widths = c(1, 1.2))
}

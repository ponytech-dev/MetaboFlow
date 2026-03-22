##############################################################################
##  templates/advanced/dual_volcano.R
##  A21 — Dual contrast volcano comparison (side by side)
##
##  md$uns$contrasts: named list with ≥2 contrast data.frames
##    each containing: feature_id, logFC, pvalue, optional compound_name
##  params: contrast_a, contrast_b (default: first two)
##          fc_cut (default 1), p_cut (default 0.05), label_overlap (default 15)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

.single_volcano <- function(df, title, fc_cut, p_cut, label_overlap) {
  library(ggplot2)
  library(ggrepel)

  df$neg_log10_p <- -log10(pmax(df$pvalue, 1e-300))
  df$regulation  <- dplyr::case_when(
    df$logFC >= fc_cut  & df$pvalue <= p_cut ~ "Up",
    df$logFC <= -fc_cut & df$pvalue <= p_cut ~ "Down",
    TRUE                                     ~ "Not"
  )

  n_up   <- sum(df$regulation == "Up")
  n_down <- sum(df$regulation == "Down")

  df$label <- ""
  sig_mask <- df$regulation != "Not"
  if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    df$label[sig_mask] <- ifelse(is.na(df$compound_name[sig_mask]),
                                  df$feature_id[sig_mask],
                                  df$compound_name[sig_mask])
  } else {
    df$label[sig_mask] <- df$feature_id[sig_mask]
  }

  ggplot(df, aes(x = logFC, y = neg_log10_p, color = regulation)) +
    geom_hline(yintercept = -log10(p_cut), linetype = "dashed",
               color = "grey60", linewidth = 0.5) +
    geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed",
               color = "grey60", linewidth = 0.5) +
    geom_point(size = 2, alpha = 0.75) +
    geom_text_repel(aes(label = label), size = 2.5, max.overlaps = label_overlap,
                    segment.color = "grey50", segment.size = 0.3) +
    scale_color_manual(values = mf_volcano_colors, name = NULL) +
    annotate("text", x = max(df$logFC) * 0.8, y = max(df$neg_log10_p) * 0.95,
             label = sprintf("↑%d  ↓%d", n_up, n_down), size = 3.5, color = "grey30") +
    labs(title = title, x = "log2FC", y = "-log10(p)") +
    theme_metaboflow() +
    theme(legend.position = "none")
}

render_dual_volcano <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  contrasts <- md$uns$contrasts
  if (is.null(contrasts) || length(contrasts) < 2) {
    return(.placeholder_plot(
      "dual_volcano requires md$uns$contrasts with at least 2 contrasts"
    ))
  }

  ct_names  <- names(contrasts)
  ca_name   <- if (!is.null(params$contrast_a)) params$contrast_a else ct_names[1]
  cb_name   <- if (!is.null(params$contrast_b)) params$contrast_b else ct_names[2]
  fc_cut    <- if (!is.null(params$fc_cut))     params$fc_cut     else 1
  p_cut     <- if (!is.null(params$p_cut))      params$p_cut      else 0.05
  label_ovl <- if (!is.null(params$label_overlap)) params$label_overlap else 15

  ca <- contrasts[[ca_name]]
  cb <- contrasts[[cb_name]]

  if (is.null(ca)) return(.placeholder_plot(sprintf("Contrast '%s' not found", ca_name)))
  if (is.null(cb)) return(.placeholder_plot(sprintf("Contrast '%s' not found", cb_name)))

  # Add compound names from md$var if missing
  var <- md$var
  .add_names <- function(ct) {
    if (is.null(ct$compound_name) && !is.null(var$compound_name)) {
      ct$compound_name <- var$compound_name[match(ct$feature_id, var$feature_id)]
    }
    ct
  }
  ca <- .add_names(ca)
  cb <- .add_names(cb)

  pa <- .single_volcano(ca, sprintf("Volcano: %s", ca_name), fc_cut, p_cut, label_ovl)
  pb <- .single_volcano(cb, sprintf("Volcano: %s", cb_name), fc_cut, p_cut, label_ovl)

  # Find overlapping significant features
  sig_a <- ca$feature_id[!is.na(ca$logFC) & !is.na(ca$pvalue) &
                            abs(ca$logFC) >= fc_cut & ca$pvalue <= p_cut]
  sig_b <- cb$feature_id[!is.na(cb$logFC) & !is.na(cb$pvalue) &
                            abs(cb$logFC) >= fc_cut & cb$pvalue <= p_cut]
  n_shared <- length(intersect(sig_a, sig_b))

  (pa | pb) +
    plot_annotation(
      title   = sprintf("Dual Volcano: %s vs %s", ca_name, cb_name),
      caption = sprintf("Shared significant features: %d", n_shared)
    )
}

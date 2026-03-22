##############################################################################
##  templates/advanced/enhanced_volcano_annotated.R
##  A01 — Enhanced Volcano with annotation level coloring + compound labels
##
##  md$var: feature_id, logFC, pvalue, optional compound_name, schymanski_level
##  params: fc_cut (default 1), p_cut (default 0.05), label_sig (default TRUE)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_enhanced_volcano_annotated <- function(md, params) {
  library(ggplot2)
  library(ggrepel)

  var <- md$var
  if (is.null(var$logFC) || is.null(var$pvalue)) {
    return(.placeholder_plot("enhanced_volcano_annotated requires md$var$logFC and md$var$pvalue"))
  }

  fc_cut    <- if (!is.null(params$fc_cut))    params$fc_cut    else 1
  p_cut     <- if (!is.null(params$p_cut))     params$p_cut     else 0.05
  label_sig <- if (!is.null(params$label_sig)) params$label_sig else TRUE

  df <- var
  df$neg_log10_p <- -log10(pmax(df$pvalue, 1e-300))

  # Schymanski confidence level — 1 (best) to 5 (worst), NA if absent
  if (!is.null(df$schymanski_level) && any(!is.na(df$schymanski_level))) {
    df$anno_level <- factor(
      ifelse(is.na(df$schymanski_level), "Unannotated",
             paste0("Level ", df$schymanski_level)),
      levels = c("Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Unannotated")
    )
  } else {
    df$anno_level <- factor("Unannotated")
  }

  # Regulation direction
  df$regulation <- dplyr::case_when(
    df$logFC >= fc_cut & df$pvalue <= p_cut  ~ "Up",
    df$logFC <= -fc_cut & df$pvalue <= p_cut ~ "Down",
    TRUE                                     ~ "Not"
  )

  # Color by annotation level
  anno_colors <- c(
    "Level 1" = mf_colors$up,
    "Level 2" = "#F39B7F",
    "Level 3" = "#8491B4",
    "Level 4" = mf_colors$down,
    "Level 5" = "#7E6148",
    "Unannotated" = mf_colors$not_significant
  )
  # Only keep levels present in data
  present_levels <- levels(droplevels(df$anno_level))
  anno_colors    <- anno_colors[names(anno_colors) %in% present_levels]

  # Labels for significant + annotated points
  df$label <- ""
  if (label_sig) {
    sig_mask  <- df$regulation != "Not"
    has_name  <- !is.null(df$compound_name) && any(!is.na(df$compound_name))
    df$label[sig_mask] <- if (has_name) {
      ifelse(is.na(df$compound_name[sig_mask]), df$feature_id[sig_mask], df$compound_name[sig_mask])
    } else {
      df$feature_id[sig_mask]
    }
  }

  # Shape: up/down/not
  df$shape <- dplyr::case_when(
    df$regulation == "Up"   ~ 24L,
    df$regulation == "Down" ~ 25L,
    TRUE                    ~ 21L
  )

  ggplot(df, aes(x = logFC, y = neg_log10_p, fill = anno_level)) +
    geom_hline(yintercept = -log10(p_cut), linetype = "dashed", color = "grey60", linewidth = 0.5) +
    geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed", color = "grey60", linewidth = 0.5) +
    geom_point(aes(shape = shape), size = 2.5, alpha = 0.85, color = "white", stroke = 0.3) +
    scale_shape_identity() +
    scale_fill_manual(values = anno_colors, drop = TRUE, name = "Annotation Level") +
    geom_text_repel(
      aes(label = label),
      size = 2.8, max.overlaps = 20,
      segment.color = "grey50", segment.size = 0.3
    ) +
    labs(
      title    = "Enhanced Volcano — Annotation Level Coloring",
      subtitle = sprintf("FC cutoff: %g | p cutoff: %g", fc_cut, p_cut),
      x        = "log2 Fold Change",
      y        = "-log10(p-value)"
    ) +
    theme_metaboflow() +
    theme(legend.position = "right")
}

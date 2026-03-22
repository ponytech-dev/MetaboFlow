##############################################################################
##  templates/advanced/analysis_dashboard.R
##  A30 — Comprehensive analysis dashboard (4-panel)
##
##  Panels:
##    P1 (top-left) : PCA score plot (reuses pca_score logic)
##    P2 (top-right): Volcano plot (reuses volcano_plot logic)
##    P3 (bot-left) : Top-N differential features heatmap (reuses heatmap_clustered)
##    P4 (bot-right): Pathway enrichment bubble (from md$uns$pathway_results)
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group
##  md$var: feature_id, logFC, pvalue, optional compound_name
##  md$uns$pathway_results: optional pathway enrichment data.frame
##  params: fc_cut (default 1), p_cut (default 0.05),
##          top_n_heatmap (default 30), top_pathways (default 15)
##############################################################################

render_analysis_dashboard <- function(md, params) {
  library(ggplot2)
  library(patchwork)
  library(ComplexHeatmap)

  fc_cut        <- if (!is.null(params$fc_cut))         params$fc_cut         else 1
  p_cut         <- if (!is.null(params$p_cut))          params$p_cut          else 0.05
  top_n_heatmap <- if (!is.null(params$top_n_heatmap))  params$top_n_heatmap  else 30
  top_pathways  <- if (!is.null(params$top_pathways))   params$top_pathways   else 15

  X   <- md$X
  obs <- md$obs
  var <- md$var

  # =========================================================================
  # Panel 1: PCA score plot
  # =========================================================================
  p1 <- tryCatch({
    col_var <- apply(X, 2, var, na.rm = TRUE)
    X_pca   <- X[, col_var > 0, drop = FALSE]
    for (j in seq_len(ncol(X_pca))) {
      nas <- is.na(X_pca[, j])
      if (any(nas)) X_pca[nas, j] <- mean(X_pca[, j], na.rm = TRUE)
    }
    pca     <- prcomp(X_pca, scale. = TRUE, center = TRUE)
    var_exp <- summary(pca)$importance[2, ] * 100
    scores  <- as.data.frame(pca$x[, 1:2])
    colnames(scores) <- c("PC1", "PC2")
    scores$group     <- obs$group

    ggplot(scores, aes(x = PC1, y = PC2, color = group)) +
      stat_ellipse(aes(fill = group), geom = "polygon",
                   level = 0.95, alpha = 0.08, linetype = "dashed") +
      geom_point(size = 2.5, alpha = 0.9) +
      scale_color_metaboflow() + scale_fill_metaboflow() +
      labs(title = "PCA",
           x = sprintf("PC1 (%.1f%%)", var_exp[1]),
           y = sprintf("PC2 (%.1f%%)", var_exp[2]),
           color = "Group", fill = "Group") +
      theme_metaboflow() +
      theme(legend.position = "right", legend.text = element_text(size = 7))
  }, error = function(e) {
    ggplot() + annotate("text", x=0.5, y=0.5, label=paste("PCA failed:", e$message),
                         size=3.5, color="grey50") + theme_void() + xlim(0,1) + ylim(0,1)
  })

  # =========================================================================
  # Panel 2: Volcano plot
  # =========================================================================
  p2 <- tryCatch({
    if (is.null(var$logFC) || is.null(var$pvalue)) stop("logFC or pvalue missing")

    df             <- var
    df$neg_log10_p <- -log10(pmax(df$pvalue, 1e-300))
    df$regulation  <- dplyr::case_when(
      df$logFC >= fc_cut  & df$pvalue <= p_cut ~ "Up",
      df$logFC <= -fc_cut & df$pvalue <= p_cut ~ "Down",
      TRUE                                     ~ "Not"
    )

    n_up   <- sum(df$regulation == "Up")
    n_down <- sum(df$regulation == "Down")

    ggplot(df, aes(x = logFC, y = neg_log10_p, color = regulation)) +
      geom_hline(yintercept = -log10(p_cut), linetype = "dashed",
                 color = "grey60", linewidth = 0.4) +
      geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed",
                 color = "grey60", linewidth = 0.4) +
      geom_point(size = 1.5, alpha = 0.7) +
      scale_color_manual(values = mf_volcano_colors, name = NULL) +
      annotate("text", x = Inf, y = Inf, hjust = 1.1, vjust = 1.5,
               label = sprintf("↑%d  ↓%d", n_up, n_down),
               size = 3, color = "grey30") +
      labs(title = "Volcano", x = "log2FC", y = "-log10(p)") +
      theme_metaboflow() +
      theme(legend.position = "none")
  }, error = function(e) {
    ggplot() + annotate("text", x=0.5, y=0.5,
                         label=paste("Volcano failed\n(need logFC + pvalue)"),
                         size=3.5, color="grey50") + theme_void() + xlim(0,1) + ylim(0,1)
  })

  # =========================================================================
  # Panel 3: Differential features heatmap (ComplexHeatmap → grob)
  # =========================================================================
  p3 <- tryCatch({
    library(circlize)

    if (!is.null(var$pvalue) && !all(is.na(var$pvalue))) {
      ord <- order(var$pvalue, na.last = TRUE)
    } else {
      ord <- order(apply(X, 2, var, na.rm = TRUE), decreasing = TRUE)
    }

    n_feat  <- min(top_n_heatmap, ncol(X))
    sel     <- ord[seq_len(n_feat)]
    X_sub   <- X[, sel, drop = FALSE]
    var_sub <- var[sel, , drop = FALSE]

    mat        <- t(X_sub)
    mat_scaled <- t(scale(t(mat)))
    mat_scaled[mat_scaled >  3] <-  3
    mat_scaled[mat_scaled < -3] <- -3

    group_colors <- group_color_map(obs$group)
    col_anno     <- HeatmapAnnotation(
      Group = obs$group,
      col   = list(Group = group_colors),
      annotation_name_gp = gpar(fontsize = 7),
      simple_anno_size = unit(3, "mm")
    )

    hm <- Heatmap(
      mat_scaled,
      name              = "Z-score",
      col               = colorRamp2(c(-3, 0, 3), mf_diverging(3)),
      top_annotation    = col_anno,
      show_row_names    = n_feat <= 40,
      row_names_gp      = gpar(fontsize = 5),
      column_names_gp   = gpar(fontsize = 6),
      clustering_distance_rows    = "euclidean",
      clustering_distance_columns = "euclidean",
      clustering_method_rows      = "ward.D2",
      clustering_method_columns   = "ward.D2",
      column_title     = sprintf("Top %d Features", n_feat),
      column_title_gp  = gpar(fontsize = 8, fontface = "bold"),
      heatmap_legend_param = list(title_gp = gpar(fontsize = 7),
                                   labels_gp = gpar(fontsize = 6))
    )

    hm_grob <- grid::grid.grabExpr(draw(hm), wrap = TRUE)
    patchwork::wrap_elements(hm_grob)

  }, error = function(e) {
    ggplot() + annotate("text", x=0.5, y=0.5,
                         label=paste("Heatmap failed:", e$message),
                         size=3, color="grey50") + theme_void() + xlim(0,1) + ylim(0,1)
  })

  # =========================================================================
  # Panel 4: Pathway enrichment bubble
  # =========================================================================
  pw_res <- md$uns$pathway_results
  p4 <- tryCatch({
    if (is.null(pw_res) || nrow(pw_res) == 0) {
      stop("No pathway results")
    }

    pw_res <- pw_res[!is.na(pw_res$p_value), ]
    pw_res <- pw_res[order(pw_res$p_value), ]
    pw_res <- head(pw_res, top_pathways)
    pw_res$neg_log10_p    <- -log10(pmax(pw_res$p_value, 1e-300))
    pw_res$pathway_name_f <- factor(pw_res$pathway_name, levels = rev(pw_res$pathway_name))

    x_var <- if (!is.null(pw_res$ratio))  "ratio" else
              if (!is.null(pw_res$count)) "count" else NULL
    if (is.null(x_var)) stop("pathway_results needs ratio or count")

    ggplot(pw_res,
           aes(x = .data[[x_var]], y = pathway_name_f,
               size = if (!is.null(pw_res$count)) count else 1,
               color = neg_log10_p)) +
      geom_point(alpha = 0.9) +
      scale_color_gradientn(colors = mf_pathway(100), name = "-log10(p)") +
      scale_size_continuous(range = c(2, 8), name = "Hits") +
      labs(title = "Pathways",
           x = if (x_var == "ratio") "Enrichment Ratio" else "Hit Count",
           y = NULL) +
      theme_metaboflow() +
      theme(axis.text.y = element_text(size = 7),
            legend.position = "right",
            legend.key.size = unit(0.4, "cm"))

  }, error = function(e) {
    msg <- if (is.null(pw_res)) "Pathway data not provided\n(md$uns$pathway_results)" else e$message
    ggplot() + annotate("text", x=0.5, y=0.5, label=msg, size=3.5, color="grey50") +
      theme_void() + xlim(0,1) + ylim(0,1)
  })

  # =========================================================================
  # Assemble 2×2
  # =========================================================================
  n_sig_total <- if (!is.null(var$pvalue) && !is.null(var$logFC)) {
    sum(!is.na(var$pvalue) & var$pvalue <= p_cut &
          !is.na(var$logFC) & abs(var$logFC) >= fc_cut)
  } else { NA }

  (p1 | p2) / (p3 | p4) +
    plot_annotation(
      title   = "MetaboFlow Analysis Dashboard",
      caption = sprintf(
        "Samples: %d  |  Features: %d  |  Significant: %s  |  FC cut: %g  |  p cut: %g",
        nrow(X), ncol(X),
        if (is.na(n_sig_total)) "—" else as.character(n_sig_total),
        fc_cut, p_cut
      ),
      theme = theme(plot.title = element_text(size = 14, face = "bold"))
    )
}

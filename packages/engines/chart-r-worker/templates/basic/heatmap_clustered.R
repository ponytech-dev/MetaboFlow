##############################################################################
##  templates/basic/heatmap_clustered.R
##  Hierarchical clustering heatmap of top-N significant features
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with column: group
##  md$var: feature metadata — needs pvalue for feature selection;
##          logFC used for row annotation if present
##  params: top_n (default 50)
##############################################################################

render_heatmap_clustered <- function(md, params) {
  library(ComplexHeatmap)
  library(circlize)

  top_n <- if (!is.null(params$top_n)) params$top_n else 50

  X   <- md$X
  obs <- md$obs
  var <- md$var

  # Select top features by pvalue if available, else by variance
  if (!is.null(var$pvalue) && !all(is.na(var$pvalue))) {
    ord <- order(var$pvalue, na.last = TRUE)
  } else {
    warning("heatmap_clustered: md$var$pvalue not found — using top variance features")
    row_vars <- apply(X, 2, var, na.rm = TRUE)
    ord <- order(row_vars, decreasing = TRUE)
  }

  n_features <- min(top_n, ncol(X))
  sel_idx    <- ord[seq_len(n_features)]
  X_sub      <- X[, sel_idx, drop = FALSE]
  var_sub    <- var[sel_idx, , drop = FALSE]

  # Z-score scale rows (per feature, i.e. column of X_sub transposed → row of heatmap)
  # Heatmap: rows = features, cols = samples → transpose X_sub
  mat <- t(X_sub)  # features × samples

  # Scale each feature (row) to z-score
  mat_scaled <- t(scale(t(mat)))

  # Clip extreme z-scores for visual clarity
  mat_scaled[mat_scaled >  3] <-  3
  mat_scaled[mat_scaled < -3] <- -3

  # --- Column annotation: group ---
  group_levels <- unique(obs$group)
  group_colors <- group_color_map(obs$group)
  col_anno <- HeatmapAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    annotation_name_gp = gpar(fontsize = 9)
  )

  # --- Row annotation: logFC ---
  row_anno <- NULL
  if (!is.null(var_sub$logFC) && !all(is.na(var_sub$logFC))) {
    fc_vals  <- var_sub$logFC
    fc_range <- max(abs(fc_vals), na.rm = TRUE)
    fc_col   <- colorRamp2(
      c(-fc_range, 0, fc_range),
      c(mf_colors$down, "white", mf_colors$up)
    )
    row_anno <- rowAnnotation(
      logFC = fc_vals,
      col   = list(logFC = fc_col),
      annotation_name_gp = gpar(fontsize = 9)
    )
  }

  # --- Row labels: prefer compound_name, fallback to feature_id ---
  row_labels <- if (!is.null(var_sub$compound_name) && any(!is.na(var_sub$compound_name))) {
    ifelse(is.na(var_sub$compound_name), var_sub$feature_id, var_sub$compound_name)
  } else {
    var_sub$feature_id
  }

  # Suppress long row labels if too many features
  show_row_names <- n_features <= 60

  Heatmap(
    mat_scaled,
    name                  = "Z-score",
    col                   = colorRamp2(c(-3, 0, 3), mf_diverging(3)),
    top_annotation        = col_anno,
    right_annotation      = row_anno,
    show_row_names        = show_row_names,
    row_labels            = if (show_row_names) row_labels else NULL,
    row_names_gp          = gpar(fontsize = 7),
    column_names_gp       = gpar(fontsize = 8),
    clustering_distance_rows    = "euclidean",
    clustering_distance_columns = "euclidean",
    clustering_method_rows      = "ward.D2",
    clustering_method_columns   = "ward.D2",
    column_title          = sprintf("Top %d Features (Hierarchical Clustering)", n_features),
    column_title_gp       = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param  = list(title_gp = gpar(fontsize = 9),
                                  labels_gp = gpar(fontsize = 8))
  )
}

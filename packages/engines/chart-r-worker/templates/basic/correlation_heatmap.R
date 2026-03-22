##############################################################################
##  templates/basic/correlation_heatmap.R
##  Sample-sample Pearson correlation matrix heatmap
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with columns: sample_id, group
##  params: (none specific)
##
##  Correlation: cor(t(md$X)) gives features × features.
##  We want samples × samples: t(md$X) is features × samples,
##  cor(t(md$X)) correlates columns = samples. CORRECT.
##############################################################################

render_correlation_heatmap <- function(md, params) {
  library(ComplexHeatmap)
  library(circlize)

  X   <- md$X
  obs <- md$obs

  # Impute NAs with column mean before correlation
  X_imp <- apply(X, 2, function(col) {
    m <- mean(col, na.rm = TRUE)
    col[is.na(col)] <- if (is.finite(m)) m else 0
    col
  })

  # Sample correlation: treat each sample (row of X) as a vector of features
  # cor() operates on columns, so transpose: features × samples → cor gives sample × sample
  cor_mat <- cor(t(X_imp), method = "pearson")
  rownames(cor_mat) <- obs$sample_id
  colnames(cor_mat) <- obs$sample_id

  # --- Column/Row annotation: group ---
  group_colors <- group_color_map(obs$group)
  anno <- HeatmapAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    annotation_name_gp = gpar(fontsize = 9)
  )
  row_anno <- rowAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    show_legend = FALSE,
    annotation_name_gp = gpar(fontsize = 9)
  )

  cor_col <- colorRamp2(c(-1, 0, 1), mf_diverging(3))

  n_samples <- nrow(cor_mat)
  show_names <- n_samples <= 50

  Heatmap(
    cor_mat,
    name                  = "Pearson r",
    col                   = cor_col,
    top_annotation        = anno,
    left_annotation       = row_anno,
    show_row_names        = show_names,
    show_column_names     = show_names,
    row_names_gp          = gpar(fontsize = 7),
    column_names_gp       = gpar(fontsize = 7),
    clustering_distance_rows    = "euclidean",
    clustering_distance_columns = "euclidean",
    clustering_method_rows      = "ward.D2",
    clustering_method_columns   = "ward.D2",
    column_title          = "Sample-Sample Pearson Correlation",
    column_title_gp       = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param  = list(
      title_gp  = gpar(fontsize = 9),
      labels_gp = gpar(fontsize = 8)
    )
  )
}

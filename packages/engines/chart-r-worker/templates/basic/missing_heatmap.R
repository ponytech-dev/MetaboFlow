##############################################################################
##  templates/basic/missing_heatmap.R
##  Missing value pattern heatmap — binary present/absent per feature × sample
##
##  Data source: md$layers$raw (pre-imputation) if available, else md$X
##  md$obs: sample metadata with column: group
##  md$var: feature metadata with column: feature_id
##  params: max_features (default 200 — limit rows for readability)
##############################################################################

render_missing_heatmap <- function(md, params) {
  library(ComplexHeatmap)

  max_features <- if (!is.null(params$max_features)) params$max_features else 200

  # Prefer raw layer for pre-imputation missingness
  if (!is.null(md$layers) && !is.null(md$layers$raw)) {
    X_raw   <- md$layers$raw
    src_lbl <- "Raw (pre-imputation)"
  } else {
    X_raw   <- md$X
    src_lbl <- "Current matrix"
  }

  obs <- md$obs
  var <- md$var

  # Build binary present/absent matrix: 1 = present, 0 = missing
  # Missing = NA or <= 0
  present <- matrix(
    as.integer(!is.na(X_raw) & X_raw > 0),
    nrow = nrow(X_raw),
    ncol = ncol(X_raw)
  )
  rownames(present) <- obs$sample_id
  colnames(present) <- var$feature_id

  # Sort features by % missing (descending) and cap at max_features
  pct_missing_per_feature <- 1 - colMeans(present, na.rm = TRUE)
  feat_order <- order(pct_missing_per_feature, decreasing = TRUE)

  n_feat_show <- min(max_features, ncol(present))
  feat_sel    <- feat_order[seq_len(n_feat_show)]

  mat_show <- t(present[, feat_sel, drop = FALSE])  # features × samples

  # --- Column annotation: group ---
  group_colors <- group_color_map(obs$group)
  col_anno <- HeatmapAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    annotation_name_gp = gpar(fontsize = 9)
  )

  # --- Row annotation: % missing per feature ---
  row_anno <- rowAnnotation(
    Missing = pct_missing_per_feature[feat_sel] * 100,
    col     = list(
      Missing = circlize::colorRamp2(c(0, 50, 100),
                                     c("white", "#F39B7F", mf_colors$down))
    ),
    annotation_name_gp = gpar(fontsize = 9)
  )

  show_row_names <- n_feat_show <= 80

  col_present_absent <- c("0" = "white", "1" = mf_discrete[4])  # white=missing, blue=present

  Heatmap(
    mat_show,
    name                  = "Present",
    col                   = col_present_absent,
    top_annotation        = col_anno,
    right_annotation      = row_anno,
    show_row_names        = show_row_names,
    show_column_names     = nrow(present) <= 50,
    row_names_gp          = gpar(fontsize = 6),
    column_names_gp       = gpar(fontsize = 7),
    cluster_rows          = TRUE,
    cluster_columns       = TRUE,
    clustering_method_rows    = "ward.D2",
    clustering_method_columns = "ward.D2",
    column_title = sprintf(
      "Missing Value Pattern — %s\n(Top %d features by missingness)",
      src_lbl, n_feat_show
    ),
    column_title_gp = gpar(fontsize = 10, fontface = "bold"),
    heatmap_legend_param = list(
      title_gp  = gpar(fontsize = 9),
      labels_gp = gpar(fontsize = 8),
      at        = c(0, 1),
      labels    = c("Missing", "Present")
    )
  )
}

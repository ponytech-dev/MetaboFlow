##############################################################################
##  templates/advanced/annotated_heatmap.R
##  A04 — Heatmap with ClassyFire chemical class sidebar
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group
##  md$var: feature_id, optional compound_name, cf_superclass, cf_class, logFC, pvalue
##  params: top_n (default 50)
##############################################################################

render_annotated_heatmap <- function(md, params) {
  library(ComplexHeatmap)
  library(circlize)

  top_n <- if (!is.null(params$top_n)) params$top_n else 50

  X   <- md$X
  obs <- md$obs
  var <- md$var

  # Feature selection by pvalue then variance
  if (!is.null(var$pvalue) && !all(is.na(var$pvalue))) {
    ord <- order(var$pvalue, na.last = TRUE)
  } else {
    ord <- order(apply(X, 2, var, na.rm = TRUE), decreasing = TRUE)
  }

  n_feat  <- min(top_n, ncol(X))
  sel     <- ord[seq_len(n_feat)]
  X_sub   <- X[, sel, drop = FALSE]
  var_sub <- var[sel, , drop = FALSE]

  mat        <- t(X_sub)
  mat_scaled <- t(scale(t(mat)))
  mat_scaled[mat_scaled >  3] <-  3
  mat_scaled[mat_scaled < -3] <- -3

  # ---- Column annotation: group ----
  group_colors <- group_color_map(obs$group)
  col_anno <- HeatmapAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    annotation_name_gp = gpar(fontsize = 9)
  )

  # ---- Row annotation: ClassyFire superclass ----
  row_anno_list <- list()
  row_col_list  <- list()

  if (!is.null(var_sub$cf_superclass) && any(!is.na(var_sub$cf_superclass))) {
    classes   <- ifelse(is.na(var_sub$cf_superclass), "Unknown", var_sub$cf_superclass)
    u_classes <- unique(classes)
    n_cls     <- length(u_classes)
    cls_pal   <- setNames(
      mf_discrete[((seq_len(n_cls) - 1) %% length(mf_discrete)) + 1],
      u_classes
    )
    row_anno_list$Superclass <- classes
    row_col_list$Superclass  <- cls_pal
  }

  if (!is.null(var_sub$logFC) && any(!is.na(var_sub$logFC))) {
    fc_range <- max(abs(var_sub$logFC), na.rm = TRUE)
    row_anno_list$logFC <- var_sub$logFC
    row_col_list$logFC  <- colorRamp2(c(-fc_range, 0, fc_range),
                                       c(mf_colors$down, "white", mf_colors$up))
  }

  row_anno <- if (length(row_anno_list) > 0) {
    rowAnnotation(df  = as.data.frame(row_anno_list[names(row_anno_list) == "Superclass"]),
                  logFC = if (!is.null(row_anno_list$logFC)) row_anno_list$logFC else NULL,
                  col = row_col_list,
                  annotation_name_gp = gpar(fontsize = 9))
  } else { NULL }

  # Row labels
  row_labels     <- if (!is.null(var_sub$compound_name) && any(!is.na(var_sub$compound_name))) {
    ifelse(is.na(var_sub$compound_name), var_sub$feature_id, var_sub$compound_name)
  } else { var_sub$feature_id }
  show_row_names <- n_feat <= 60

  Heatmap(
    mat_scaled,
    name              = "Z-score",
    col               = colorRamp2(c(-3, 0, 3), mf_diverging(3)),
    top_annotation    = col_anno,
    right_annotation  = row_anno,
    show_row_names    = show_row_names,
    row_labels        = if (show_row_names) row_labels else NULL,
    row_names_gp      = gpar(fontsize = 7),
    column_names_gp   = gpar(fontsize = 8),
    clustering_distance_rows    = "euclidean",
    clustering_distance_columns = "euclidean",
    clustering_method_rows      = "ward.D2",
    clustering_method_columns   = "ward.D2",
    column_title     = sprintf("Top %d Features with ClassyFire Annotation", n_feat),
    column_title_gp  = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param = list(title_gp = gpar(fontsize = 9),
                                labels_gp = gpar(fontsize = 8))
  )
}

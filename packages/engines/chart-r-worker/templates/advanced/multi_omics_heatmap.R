##############################################################################
##  templates/advanced/multi_omics_heatmap.R
##  A28 — Multi-omics integration heatmap (pathway-blocked rows)
##
##  md$uns$multi_omics: list with:
##    $metabolomics: matrix (features × samples), samples in md$obs order
##    $transcriptomics: matrix (genes × samples), same sample order
##    $proteomics: matrix (proteins × samples), same sample order (optional)
##    $pathway_annotation: data.frame — feature_id, omics_layer, pathway_name
##  md$obs: sample_id, group
##  params: top_pathways (default 10), scale_each (default TRUE)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_multi_omics_heatmap <- function(md, params) {
  library(ComplexHeatmap)
  library(circlize)

  mo <- md$uns$multi_omics
  if (is.null(mo)) {
    return(.placeholder_plot(
      "multi_omics_heatmap requires md$uns$multi_omics\n($metabolomics, $transcriptomics, and/or $proteomics)"
    ))
  }

  obs           <- md$obs
  top_pathways  <- if (!is.null(params$top_pathways))  params$top_pathways  else 10
  scale_each    <- if (!is.null(params$scale_each))    params$scale_each    else TRUE

  pw_anno <- mo$pathway_annotation

  # Collect available layers
  layers     <- list()
  layer_names <- c()
  if (!is.null(mo$metabolomics))   { layers[["Metabolomics"]]   <- mo$metabolomics }
  if (!is.null(mo$transcriptomics)) { layers[["Transcriptomics"]] <- mo$transcriptomics }
  if (!is.null(mo$proteomics))     { layers[["Proteomics"]]     <- mo$proteomics }

  if (length(layers) == 0) {
    return(.placeholder_plot("No omics matrices found in md$uns$multi_omics"))
  }

  # Z-score each layer
  .zscale <- function(mat) {
    mat_s <- t(scale(t(mat)))
    mat_s[mat_s >  3] <-  3
    mat_s[mat_s < -3] <- -3
    mat_s
  }

  scaled_layers <- if (scale_each) lapply(layers, .zscale) else layers

  # Build combined matrix — column-bind (same samples)
  # Ensure all matrices have columns = samples in obs order
  .align_cols <- function(mat) {
    matched <- match(obs$sample_id, colnames(mat))
    if (any(is.na(matched))) {
      # Try rowname matching (transposed)
      if (!is.null(rownames(mat)) && any(rownames(mat) %in% obs$sample_id)) {
        mat <- t(mat)
        matched <- match(obs$sample_id, colnames(mat))
      }
    }
    valid <- !is.na(matched)
    mat[, matched[valid], drop = FALSE]
  }

  scaled_layers <- lapply(scaled_layers, .align_cols)

  # Build pathway row-split if annotation available
  if (!is.null(pw_anno)) {
    row_splits  <- list()
    all_mats    <- list()
    block_names <- list()

    for (lyr in names(scaled_layers)) {
      mat <- scaled_layers[[lyr]]
      anno_lyr <- pw_anno[pw_anno$omics_layer == tolower(lyr) |
                            pw_anno$omics_layer == lyr, ]

      # Top pathways by feature count
      if (nrow(anno_lyr) > 0) {
        pw_counts <- sort(table(anno_lyr$pathway_name), decreasing = TRUE)
        top_pw    <- names(pw_counts)[seq_len(min(top_pathways, length(pw_counts)))]

        for (pw in top_pw) {
          feat_ids <- anno_lyr$feature_id[anno_lyr$pathway_name == pw]
          feat_ids <- intersect(feat_ids, rownames(mat))
          if (length(feat_ids) < 2) next
          all_mats[[paste0(lyr, "_", pw)]]    <- mat[feat_ids, , drop = FALSE]
          block_names[[paste0(lyr, "_", pw)]] <- sprintf("%s\n%s", lyr, pw)
        }
      } else {
        # No annotation — include all rows of this layer
        all_mats[[lyr]]    <- mat
        block_names[[lyr]] <- lyr
      }
    }
  } else {
    # No pathway annotation — use all rows, split by layer
    all_mats    <- scaled_layers
    block_names <- as.list(names(scaled_layers))
  }

  if (length(all_mats) == 0) {
    return(.placeholder_plot("No features matched between omics matrices and annotations"))
  }

  combined_mat <- do.call(rbind, all_mats)
  row_split_vec <- rep(unlist(block_names),
                        times = sapply(all_mats, nrow))

  # Column annotation
  group_colors <- group_color_map(obs$group)
  col_anno     <- HeatmapAnnotation(
    Group = obs$group,
    col   = list(Group = group_colors),
    annotation_name_gp = gpar(fontsize = 9)
  )

  col_fun <- colorRamp2(c(-3, 0, 3), mf_diverging(3))

  Heatmap(
    combined_mat,
    name              = "Z-score",
    col               = col_fun,
    top_annotation    = col_anno,
    row_split         = row_split_vec,
    cluster_row_slices = FALSE,
    show_row_names    = nrow(combined_mat) <= 100,
    row_names_gp      = gpar(fontsize = 5),
    column_names_gp   = gpar(fontsize = 8),
    clustering_distance_columns = "euclidean",
    clustering_method_columns   = "ward.D2",
    cluster_rows      = TRUE,
    row_title_gp      = gpar(fontsize = 7),
    column_title      = "Multi-Omics Integration Heatmap",
    column_title_gp   = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param = list(title_gp = gpar(fontsize = 9),
                                 labels_gp = gpar(fontsize = 8))
  )
}

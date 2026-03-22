##############################################################################
##  templates/basic/pca_loading.R
##  PCA Loading / Biplot — feature contributions overlaid on score plot
##
##  md$X: samples x features matrix (required)
##  md$obs: must contain sample_id, group
##  md$var: feature_id, optionally compound_name
##  params:
##    pc_x       (default 1) — PC on x-axis
##    pc_y       (default 2) — PC on y-axis
##    top_n      (default 10) — number of loading vectors to draw
##    scale      (default TRUE) — center/scale before PCA
##    arrow_scale (default 0.7) — multiplier to fit arrows inside score cloud
##############################################################################

render_pca_loading <- function(md, params) {
  X <- md$X
  if (is.null(X) || !is.matrix(X)) {
    return(.placeholder_plot("pca_loading: md$X must be a numeric matrix"))
  }

  pc_x       <- if (!is.null(params$pc_x))       as.integer(params$pc_x)       else 1L
  pc_y       <- if (!is.null(params$pc_y))       as.integer(params$pc_y)       else 2L
  top_n      <- if (!is.null(params$top_n))      as.integer(params$top_n)      else 10L
  do_scale   <- if (!is.null(params$scale))      isTRUE(params$scale)          else TRUE
  arw_scale  <- if (!is.null(params$arrow_scale)) params$arrow_scale            else 0.7

  # Remove columns with zero / near-zero variance before PCA
  col_sd <- apply(X, 2, sd, na.rm = TRUE)
  X <- X[, col_sd > 1e-10, drop = FALSE]
  if (ncol(X) < 2) {
    return(.placeholder_plot("pca_loading: fewer than 2 variable features after variance filter"))
  }

  pca    <- prcomp(X, center = TRUE, scale. = do_scale)
  n_pc   <- ncol(pca$rotation)
  pc_x   <- min(pc_x, n_pc)
  pc_y   <- min(pc_y, n_pc)

  # Variance explained
  var_pct <- round(summary(pca)$importance[2, ] * 100, 1)

  # Scores data frame
  scores_df <- data.frame(
    pc_a     = pca$x[, pc_x],
    pc_b     = pca$x[, pc_y],
    sample_id = rownames(pca$x),
    stringsAsFactors = FALSE
  )
  if (!is.null(md$obs$group)) {
    scores_df$group <- md$obs$group[match(scores_df$sample_id, md$obs$sample_id)]
  } else {
    scores_df$group <- "All"
  }

  # Select top-N loading vectors by combined magnitude on the two PCs
  rot      <- pca$rotation[, c(pc_x, pc_y), drop = FALSE]
  magnitude <- sqrt(rot[, 1]^2 + rot[, 2]^2)
  top_idx  <- order(magnitude, decreasing = TRUE)[seq_len(min(top_n, nrow(rot)))]
  rot_top  <- as.data.frame(rot[top_idx, , drop = FALSE])
  colnames(rot_top) <- c("pc_a", "pc_b")
  rot_top$feature_id <- rownames(rot_top)

  # Attach compound names if available
  if (!is.null(md$var$compound_name)) {
    cn_map <- setNames(md$var$compound_name, md$var$feature_id)
    rot_top$label <- ifelse(
      is.na(cn_map[rot_top$feature_id]) | cn_map[rot_top$feature_id] == "",
      rot_top$feature_id,
      cn_map[rot_top$feature_id]
    )
  } else {
    rot_top$label <- rot_top$feature_id
  }

  # Scale arrows to fit within score cloud (fraction of score range)
  score_range <- max(abs(c(scores_df$pc_a, scores_df$pc_b)))
  rot_range   <- max(abs(c(rot_top$pc_a, rot_top$pc_b)))
  if (rot_range > 0) {
    scale_factor <- arw_scale * score_range / rot_range
  } else {
    scale_factor <- 1
  }
  rot_top$pc_a_s <- rot_top$pc_a * scale_factor
  rot_top$pc_b_s <- rot_top$pc_b * scale_factor

  ggplot() +
    # Score points
    geom_point(
      data    = scores_df,
      mapping = aes(x = pc_a, y = pc_b, color = group),
      size    = 2.5, alpha = 0.8
    ) +
    # Loading arrows
    geom_segment(
      data    = rot_top,
      mapping = aes(x = 0, y = 0, xend = pc_a_s, yend = pc_b_s),
      arrow   = arrow(length = unit(0.2, "cm"), type = "closed"),
      color   = "grey30", linewidth = 0.5, alpha = 0.7
    ) +
    # Loading labels
    geom_text(
      data    = rot_top,
      mapping = aes(x = pc_a_s * 1.08, y = pc_b_s * 1.08, label = label),
      size    = 2.8, color = "grey20"
    ) +
    scale_color_metaboflow() +
    labs(
      title    = "PCA Loading / Biplot",
      subtitle = sprintf("Top %d feature vectors | PC%d vs PC%d", top_n, pc_x, pc_y),
      x        = sprintf("PC%d (%.1f%%)", pc_x, var_pct[pc_x]),
      y        = sprintf("PC%d (%.1f%%)", pc_y, var_pct[pc_y]),
      color    = "Group"
    ) +
    theme_metaboflow()
}

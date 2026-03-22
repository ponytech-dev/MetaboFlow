##############################################################################
##  templates/basic/pca_score.R
##  PCA score plot — PC1 vs PC2 with confidence ellipses
##
##  md$X  : samples × features matrix
##  md$obs: sample metadata with columns: sample_id, group
##  params: pc_x (default 1), pc_y (default 2), ellipse_level (default 0.95)
##############################################################################

render_pca_score <- function(md, params) {
  library(ggplot2)

  X <- md$X
  obs <- md$obs

  # Remove features with zero variance before PCA
  col_var <- apply(X, 2, var, na.rm = TRUE)
  X <- X[, col_var > 0, drop = FALSE]

  if (ncol(X) < 2) {
    stop("pca_score: fewer than 2 variable features after filtering")
  }

  # Impute remaining NAs with column mean
  for (j in seq_len(ncol(X))) {
    nas <- is.na(X[, j])
    if (any(nas)) X[nas, j] <- mean(X[, j], na.rm = TRUE)
  }

  pca <- prcomp(X, scale. = TRUE, center = TRUE)

  pc_x <- if (!is.null(params$pc_x)) params$pc_x else 1
  pc_y <- if (!is.null(params$pc_y)) params$pc_y else 2

  var_exp <- summary(pca)$importance[2, ] * 100  # % variance explained

  scores <- as.data.frame(pca$x[, c(pc_x, pc_y)])
  colnames(scores) <- c("PC_x", "PC_y")
  scores$group     <- obs$group
  scores$sample_id <- obs$sample_id

  ellipse_level <- if (!is.null(params$ellipse_level)) params$ellipse_level else 0.95

  ggplot(scores, aes(x = PC_x, y = PC_y, color = group)) +
    stat_ellipse(aes(fill = group), geom = "polygon",
                 level = ellipse_level, alpha = 0.08, linetype = "dashed") +
    geom_point(size = 3, alpha = 0.9) +
    scale_color_metaboflow() +
    scale_fill_metaboflow() +
    labs(
      title = "PCA Score Plot",
      x = sprintf("PC%d (%.1f%%)", pc_x, var_exp[pc_x]),
      y = sprintf("PC%d (%.1f%%)", pc_y, var_exp[pc_y]),
      color = "Group",
      fill  = "Group"
    ) +
    theme_metaboflow()
}

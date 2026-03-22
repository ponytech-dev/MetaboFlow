##############################################################################
##  templates/basic/plsda_score.R
##  PLS-DA score plot — supervised classification
##
##  Requires mixOmics package. Falls back to PCA score plot with a warning
##  if mixOmics is not installed.
##
##  md$X: samples x features matrix
##  md$obs: sample_id, group (group is the Y response)
##  params:
##    ncomp    (default 2) — number of PLS components
##    pc_x     (default 1)
##    pc_y     (default 2)
##    ellipse  (default TRUE) — draw 95% confidence ellipses per group
##############################################################################

render_plsda_score <- function(md, params) {
  X <- md$X
  if (is.null(X) || !is.matrix(X)) {
    return(.placeholder_plot("plsda_score: md$X must be a numeric matrix"))
  }
  if (is.null(md$obs$group)) {
    return(.placeholder_plot("plsda_score: md$obs$group is required for PLS-DA"))
  }

  ncomp   <- if (!is.null(params$ncomp))  as.integer(params$ncomp) else 2L
  pc_x    <- if (!is.null(params$pc_x))   as.integer(params$pc_x)  else 1L
  pc_y    <- if (!is.null(params$pc_y))   as.integer(params$pc_y)  else 2L
  ellipse <- if (!is.null(params$ellipse)) isTRUE(params$ellipse)   else TRUE

  Y <- factor(md$obs$group[match(rownames(X), md$obs$sample_id)])

  has_mixomics <- requireNamespace("mixOmics", quietly = TRUE)

  if (has_mixomics) {
    model   <- mixOmics::plsda(X, Y, ncomp = max(ncomp, max(pc_x, pc_y)))
    variates <- model$variates$X

    # Metrics from cross-validation (not run here — use pre-computed if in uns)
    r2y  <- if (!is.null(model$prop_expl_var$Y)) round(sum(model$prop_expl_var$Y[1:min(ncomp,length(model$prop_expl_var$Y))]) * 100, 1) else NA
    r2x_vec <- model$prop_expl_var$X
    r2x_x <- if (!is.null(r2x_vec)) round(r2x_vec[pc_x] * 100, 1) else NA
    r2x_y <- if (!is.null(r2x_vec)) round(r2x_vec[pc_y] * 100, 1) else NA

    scores_df <- data.frame(
      comp_a = variates[, pc_x],
      comp_b = variates[, pc_y],
      group  = Y,
      stringsAsFactors = FALSE
    )

    subtitle_txt <- if (!is.na(r2y)) {
      sprintf("PLS-DA | Comp%d (R²X=%.1f%%) vs Comp%d (R²X=%.1f%%) | R²Y=%.1f%%",
              pc_x, r2x_x, pc_y, r2x_y, r2y)
    } else {
      sprintf("PLS-DA | Component %d vs Component %d", pc_x, pc_y)
    }
    x_lab <- sprintf("Component %d", pc_x)
    y_lab <- sprintf("Component %d", pc_y)
    plot_title <- "PLS-DA Score Plot"

  } else {
    # Fallback: plain PCA
    warning("mixOmics not available — showing PCA score plot as fallback")
    col_sd <- apply(X, 2, sd, na.rm = TRUE)
    X_filt <- X[, col_sd > 1e-10, drop = FALSE]
    pca    <- prcomp(X_filt, center = TRUE, scale. = TRUE)
    var_pct <- round(summary(pca)$importance[2, ] * 100, 1)
    n_pc   <- ncol(pca$x)
    pc_x   <- min(pc_x, n_pc)
    pc_y   <- min(pc_y, n_pc)

    scores_df <- data.frame(
      comp_a = pca$x[, pc_x],
      comp_b = pca$x[, pc_y],
      group  = Y,
      stringsAsFactors = FALSE
    )
    subtitle_txt <- sprintf("[Fallback PCA] PC%d (%.1f%%) vs PC%d (%.1f%%) | mixOmics not installed",
                            pc_x, var_pct[pc_x], pc_y, var_pct[pc_y])
    x_lab  <- sprintf("PC%d (%.1f%%)", pc_x, var_pct[pc_x])
    y_lab  <- sprintf("PC%d (%.1f%%)", pc_y, var_pct[pc_y])
    plot_title <- "PLS-DA Score Plot (PCA fallback)"
  }

  p <- ggplot(scores_df, aes(x = comp_a, y = comp_b, color = group, fill = group)) +
    geom_point(size = 2.5, alpha = 0.85) +
    scale_color_metaboflow() +
    scale_fill_metaboflow() +
    labs(
      title    = plot_title,
      subtitle = subtitle_txt,
      x        = x_lab,
      y        = y_lab,
      color    = "Group",
      fill     = "Group"
    ) +
    theme_metaboflow()

  if (ellipse && nlevels(Y) >= 2) {
    p <- p + stat_ellipse(geom = "polygon", alpha = 0.08, level = 0.95, linewidth = 0.6)
  }

  p
}

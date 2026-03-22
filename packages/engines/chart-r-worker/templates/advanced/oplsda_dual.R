##############################################################################
##  templates/advanced/oplsda_dual.R
##  A02 — OPLS-DA score plot + S-plot side by side (patchwork)
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group
##  params: group_a, group_b (optional — first two groups used if absent)
##          vip_cut (default 1.0) — threshold for S-plot annotation
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_oplsda_dual <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  if (!requireNamespace("ropls", quietly = TRUE)) {
    return(.placeholder_plot("ropls package required for OPLS-DA\nInstall: BiocManager::install('ropls')"))
  }

  obs   <- md$obs
  X     <- md$X
  groups <- unique(obs$group)

  group_a <- if (!is.null(params$group_a)) params$group_a else groups[1]
  group_b <- if (!is.null(params$group_b)) params$group_b else groups[min(2, length(groups))]
  vip_cut <- if (!is.null(params$vip_cut)) params$vip_cut else 1.0

  # Subset to two groups
  mask  <- obs$group %in% c(group_a, group_b)
  X_sub <- X[mask, , drop = FALSE]
  y_sub <- factor(obs$group[mask])

  # Remove zero-variance features
  col_var <- apply(X_sub, 2, var, na.rm = TRUE)
  X_sub   <- X_sub[, col_var > 0, drop = FALSE]

  # Impute NAs
  for (j in seq_len(ncol(X_sub))) {
    nas <- is.na(X_sub[, j])
    if (any(nas)) X_sub[nas, j] <- mean(X_sub[, j], na.rm = TRUE)
  }

  # Fit OPLS-DA
  oplsda_fit <- tryCatch(
    ropls::opls(X_sub, y_sub, predI = 1, orthoI = NA, printL = FALSE, plotL = FALSE),
    error = function(e) NULL
  )

  if (is.null(oplsda_fit)) {
    return(.placeholder_plot("OPLS-DA model fitting failed — check data (min 3 samples/group)"))
  }

  # ---- Score plot ----
  scores <- as.data.frame(ropls::getScoreMN(oplsda_fit))
  o_scores <- tryCatch(as.data.frame(ropls::getScoreMN(oplsda_fit, orthoL = TRUE)),
                       error = function(e) data.frame(o1 = rep(0, nrow(scores))))

  score_df <- data.frame(
    t1  = scores[, 1],
    o1  = o_scores[, 1],
    group = y_sub
  )

  p1 <- ggplot(score_df, aes(x = t1, y = o1, color = group)) +
    stat_ellipse(aes(fill = group), geom = "polygon", level = 0.95,
                 alpha = 0.08, linetype = "dashed") +
    geom_point(size = 3, alpha = 0.9) +
    scale_color_metaboflow() + scale_fill_metaboflow() +
    labs(title = "OPLS-DA Score Plot", x = "t[1] (Predictive)", y = "to[1] (Orthogonal)",
         color = "Group", fill = "Group") +
    theme_metaboflow()

  # ---- S-plot: covariance vs correlation ----
  loadings   <- tryCatch(as.numeric(ropls::getLoadingMN(oplsda_fit)[, 1]), error = function(e) NULL)
  p_loadings <- tryCatch(as.numeric(ropls::getLoadingMN(oplsda_fit, orthoL = TRUE)[, 1]),
                         error = function(e) NULL)

  if (is.null(loadings)) {
    p2 <- .placeholder_plot("S-plot loadings unavailable")
  } else {
    # Covariance and correlation of X columns with t1 scores
    t1_vec  <- score_df$t1
    cov_p   <- apply(X_sub, 2, function(x) cov(x, t1_vec, use = "complete.obs"))
    sd_x    <- apply(X_sub, 2, sd, na.rm = TRUE)
    sd_t1   <- sd(t1_vec)
    cor_p   <- cov_p / (sd_x * sd_t1 + 1e-12)

    splot_df <- data.frame(
      cov_p = cov_p,
      cor_p = cor_p,
      high_vip = abs(cor_p) >= 0.5 & abs(cov_p) >= quantile(abs(cov_p), 0.75)
    )

    p2 <- ggplot(splot_df, aes(x = cov_p, y = cor_p, color = high_vip)) +
      geom_point(size = 1.8, alpha = 0.7) +
      geom_hline(yintercept = c(-0.5, 0.5), linetype = "dashed", color = "grey60") +
      scale_color_manual(values = c("FALSE" = mf_colors$not_significant, "TRUE" = mf_colors$up),
                         labels = c("FALSE" = "Low importance", "TRUE" = "High importance"),
                         name = NULL) +
      labs(title = "S-Plot", x = "Covariance p[1]", y = "Correlation p(corr)[1]") +
      theme_metaboflow() +
      theme(legend.position = "bottom")
  }

  # Metrics annotation
  r2x <- tryCatch(round(ropls::getSummaryDF(oplsda_fit)$R2X[1], 3), error = function(e) NA)
  r2y <- tryCatch(round(ropls::getSummaryDF(oplsda_fit)$R2Y[1], 3), error = function(e) NA)
  q2  <- tryCatch(round(ropls::getSummaryDF(oplsda_fit)$Q2[1],  3), error = function(e) NA)

  (p1 | p2) +
    plot_annotation(
      title   = sprintf("OPLS-DA: %s vs %s", group_a, group_b),
      caption = sprintf("R²X = %s  |  R²Y = %s  |  Q² = %s", r2x, r2y, q2)
    )
}

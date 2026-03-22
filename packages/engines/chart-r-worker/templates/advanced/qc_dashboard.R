##############################################################################
##  templates/advanced/qc_dashboard.R
##  A20 — Multi-panel QC dashboard (patchwork 2×2)
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group, optional sample_type ("QC", "Sample", "Blank")
##  md$var: feature_id
##  Panels: (1) Sample total intensity boxplot  (2) RSD distribution
##          (3) PCA score plot                  (4) Missing value % bar
##############################################################################

render_qc_dashboard <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  X   <- md$X
  obs <- md$obs

  sample_type_col <- "sample_type"
  has_sample_type <- !is.null(obs[[sample_type_col]]) && any(!is.na(obs[[sample_type_col]]))

  if (has_sample_type) {
    type_map   <- obs[[sample_type_col]]
    type_map[is.na(type_map)] <- "Unknown"
    sample_colors <- c(
      "QC"      = mf_colors$qc,
      "Sample"  = mf_colors$group_a,
      "Blank"   = "#8491B4",
      "Unknown" = mf_colors$not_significant
    )
  } else {
    type_map      <- rep("Sample", nrow(obs))
    sample_colors <- c("Sample" = mf_colors$group_a)
  }

  # ---- Panel 1: Total intensity per sample ----
  total_int <- rowSums(X, na.rm = TRUE)
  p1_df <- data.frame(
    sample_id   = obs$sample_id,
    total_int   = total_int,
    sample_type = type_map
  )
  p1_df$sample_id <- factor(p1_df$sample_id, levels = p1_df$sample_id[order(total_int)])

  p1 <- ggplot(p1_df, aes(x = sample_id, y = log10(total_int + 1), fill = sample_type)) +
    geom_col(alpha = 0.85) +
    scale_fill_manual(values = sample_colors, name = "Type") +
    labs(title = "Total Intensity per Sample", x = NULL, y = "log10(Total Intensity)") +
    theme_metaboflow() +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
          legend.position = "none")

  # ---- Panel 2: RSD distribution (QC samples) ----
  qc_mask <- type_map == "QC"
  if (sum(qc_mask) >= 2) {
    X_qc     <- X[qc_mask, , drop = FALSE]
    rsd_vals <- apply(X_qc, 2, function(x) {
      m <- mean(x, na.rm = TRUE)
      if (is.na(m) || m == 0) return(NA_real_)
      sd(x, na.rm = TRUE) / m * 100
    })
    rsd_df   <- data.frame(rsd = rsd_vals[!is.na(rsd_vals)])
    pct_below20 <- round(mean(rsd_df$rsd <= 20) * 100, 1)

    p2 <- ggplot(rsd_df, aes(x = rsd)) +
      geom_histogram(bins = 40, fill = mf_colors$qc, alpha = 0.8, color = "white") +
      geom_vline(xintercept = 20, linetype = "dashed", color = mf_colors$up, linewidth = 0.8) +
      annotate("text", x = 22, y = Inf, label = paste0(pct_below20, "% ≤ 20%"),
               hjust = 0, vjust = 1.5, size = 3, color = mf_colors$up) +
      labs(title = "QC RSD Distribution", x = "RSD (%)", y = "Feature Count") +
      theme_metaboflow()
  } else {
    warning("qc_dashboard: <2 QC samples — RSD panel shows all-sample CV")
    cv_vals <- apply(X, 2, function(x) {
      m <- mean(x, na.rm = TRUE)
      if (is.na(m) || m == 0) return(NA_real_)
      sd(x, na.rm = TRUE) / m * 100
    })
    cv_df <- data.frame(rsd = cv_vals[!is.na(cv_vals)])
    p2 <- ggplot(cv_df, aes(x = rsd)) +
      geom_histogram(bins = 40, fill = mf_colors$not_significant, alpha = 0.8, color = "white") +
      labs(title = "CV Distribution (all samples)", x = "CV (%)", y = "Feature Count") +
      theme_metaboflow()
  }

  # ---- Panel 3: PCA score plot ----
  col_var <- apply(X, 2, var, na.rm = TRUE)
  X_pca   <- X[, col_var > 0, drop = FALSE]
  for (j in seq_len(ncol(X_pca))) {
    nas <- is.na(X_pca[, j])
    if (any(nas)) X_pca[nas, j] <- mean(X_pca[, j], na.rm = TRUE)
  }

  pca_scores <- tryCatch({
    pca  <- prcomp(X_pca, scale. = TRUE, center = TRUE)
    var_exp <- summary(pca)$importance[2, ] * 100
    df   <- as.data.frame(pca$x[, 1:min(2, ncol(pca$x))])
    colnames(df)[1:2] <- c("PC1", "PC2")
    df$sample_type <- type_map
    df$group       <- obs$group
    list(df = df, var_exp = var_exp)
  }, error = function(e) NULL)

  if (!is.null(pca_scores)) {
    pca_df <- pca_scores$df
    ve     <- pca_scores$var_exp
    p3 <- ggplot(pca_df, aes(x = PC1, y = PC2, color = group, shape = sample_type)) +
      geom_point(size = 3, alpha = 0.9) +
      scale_color_metaboflow() +
      scale_shape_manual(values = c("QC" = 17, "Sample" = 16, "Blank" = 4, "Unknown" = 3),
                          na.value = 16) +
      labs(title = "PCA Score Plot",
           x = sprintf("PC1 (%.1f%%)", ve[1]),
           y = sprintf("PC2 (%.1f%%)", ve[2]),
           color = "Group", shape = "Type") +
      theme_metaboflow() +
      theme(legend.position = "right")
  } else {
    p3 <- ggplot() + annotate("text", x=0.5, y=0.5, label="PCA failed", size=4) + theme_void()
  }

  # ---- Panel 4: Missing value % per sample ----
  miss_pct <- rowMeans(is.na(X)) * 100
  p4_df    <- data.frame(
    sample_id   = obs$sample_id,
    miss_pct    = miss_pct,
    sample_type = type_map
  )
  p4_df$sample_id <- factor(p4_df$sample_id,
                              levels = p4_df$sample_id[order(miss_pct, decreasing = TRUE)])

  p4 <- ggplot(p4_df, aes(x = sample_id, y = miss_pct, fill = sample_type)) +
    geom_col(alpha = 0.85) +
    geom_hline(yintercept = 20, linetype = "dashed", color = mf_colors$up, linewidth = 0.7) +
    scale_fill_manual(values = sample_colors, name = "Type") +
    labs(title = "Missing Values per Sample", x = NULL, y = "Missing (%)") +
    scale_y_continuous(limits = c(0, 100)) +
    theme_metaboflow() +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
          legend.position = "right")

  (p1 | p2) / (p3 | p4) +
    plot_annotation(
      title   = "QC Dashboard",
      caption = sprintf("Samples: %d  |  Features: %d  |  QC samples: %d",
                        nrow(X), ncol(X), sum(qc_mask))
    )
}

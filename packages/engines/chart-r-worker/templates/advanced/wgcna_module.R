##############################################################################
##  templates/advanced/wgcna_module.R
##  A22 — WGCNA module-trait heatmap
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group, optional phenotype columns (numeric clinical vars)
##  md$uns$wgcna_results: optional pre-computed list with:
##    $module_colors: named vector (feature_id → module color)
##    $module_trait: data.frame (module × trait) of Pearson r values
##    $module_trait_p: data.frame (module × trait) of p-values
##  params: trait_cols (character vector of obs column names to use as traits)
##          soft_power (default 6), min_module_size (default 20)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_wgcna_module <- function(md, params) {
  library(ggplot2)
  library(ComplexHeatmap)
  library(circlize)

  if (!requireNamespace("WGCNA", quietly = TRUE)) {
    return(.placeholder_plot(
      "WGCNA package required\nInstall: install.packages('WGCNA')"
    ))
  }

  # Use pre-computed results if available
  wgcna_res <- md$uns$wgcna_results

  if (is.null(wgcna_res)) {
    X   <- md$X
    obs <- md$obs

    # Identify numeric trait columns
    trait_cols <- params$trait_cols
    if (is.null(trait_cols)) {
      trait_cols <- colnames(obs)[sapply(obs, is.numeric)]
      trait_cols <- setdiff(trait_cols, c("sample_id"))
    }

    if (length(trait_cols) == 0) {
      return(.placeholder_plot(
        "wgcna_module: no numeric trait columns found in md$obs\nProvide params$trait_cols"
      ))
    }

    # Impute and filter
    col_var <- apply(X, 2, var, na.rm = TRUE)
    X       <- X[, col_var > 0, drop = FALSE]
    for (j in seq_len(ncol(X))) {
      nas <- is.na(X[, j])
      if (any(nas)) X[nas, j] <- mean(X[, j], na.rm = TRUE)
    }

    soft_power      <- if (!is.null(params$soft_power))      params$soft_power      else 6
    min_module_size <- if (!is.null(params$min_module_size)) params$min_module_size else 20

    # Run WGCNA
    module_colors <- tryCatch({
      net <- WGCNA::blockwiseModules(
        X,
        power             = soft_power,
        minModuleSize     = min_module_size,
        reassignThreshold = 0,
        mergeCutHeight    = 0.25,
        numericLabels     = FALSE,
        verbose           = 0
      )
      net$colors
    }, error = function(e) { message("WGCNA error: ", e$message); NULL })

    if (is.null(module_colors)) {
      return(.placeholder_plot("WGCNA blockwiseModules failed"))
    }

    # Module eigengenes
    me_list <- WGCNA::moduleEigengenes(X, colors = module_colors)
    MEs     <- me_list$eigengenes

    # Module-trait correlation
    trait_mat <- as.matrix(obs[, trait_cols, drop = FALSE])
    trait_mat <- apply(trait_mat, 2, as.numeric)

    n_samples <- nrow(MEs)
    cor_mat   <- matrix(NA, ncol(MEs), ncol(trait_mat),
                         dimnames = list(colnames(MEs), trait_cols))
    p_mat     <- cor_mat

    for (i in seq_len(ncol(MEs))) {
      for (j in seq_len(ncol(trait_mat))) {
        complete <- !is.na(MEs[, i]) & !is.na(trait_mat[, j])
        if (sum(complete) < 5) next
        ct <- tryCatch(cor.test(MEs[complete, i], trait_mat[complete, j]), error = function(e) NULL)
        if (!is.null(ct)) {
          cor_mat[i, j] <- ct$estimate
          p_mat[i, j]   <- ct$p.value
        }
      }
    }

    wgcna_res <- list(
      module_trait   = as.data.frame(cor_mat),
      module_trait_p = as.data.frame(p_mat)
    )
  }

  cor_mat <- as.matrix(wgcna_res$module_trait)
  p_mat   <- as.matrix(wgcna_res$module_trait_p)

  if (is.null(cor_mat) || nrow(cor_mat) == 0) {
    return(.placeholder_plot("No module-trait correlation data"))
  }

  # Remove all-NA rows/cols
  keep_rows <- rowSums(!is.na(cor_mat)) > 0
  keep_cols <- colSums(!is.na(cor_mat)) > 0
  cor_mat   <- cor_mat[keep_rows, keep_cols, drop = FALSE]
  p_mat     <- p_mat[keep_rows, keep_cols, drop = FALSE]

  # Cell label: r\np
  cell_labels <- matrix(
    sprintf("%.2f\n(%s)", cor_mat, ifelse(is.na(p_mat), "—",
                                           ifelse(p_mat < 0.001, "<0.001",
                                                  sprintf("%.3f", p_mat)))),
    nrow = nrow(cor_mat)
  )

  col_fun <- colorRamp2(c(-1, 0, 1),
                         c(mf_colors$down, "white", mf_colors$up))

  Heatmap(
    cor_mat,
    name             = "Pearson r",
    col              = col_fun,
    cell_fun         = function(j, i, x, y, width, height, fill) {
      grid::grid.text(cell_labels[i, j], x, y,
                       gp = grid::gpar(fontsize = 7, col = "grey20"))
    },
    cluster_rows     = TRUE,
    cluster_columns  = TRUE,
    row_names_gp     = gpar(fontsize = 8),
    column_names_gp  = gpar(fontsize = 8),
    column_title     = "WGCNA Module–Trait Correlation",
    column_title_gp  = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param = list(title_gp = gpar(fontsize = 9),
                                 labels_gp = gpar(fontsize = 8))
  )
}

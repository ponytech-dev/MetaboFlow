##############################################################################
##  templates/advanced/metabolite_phenotype.R
##  A25 — Metabolite-phenotype correlation heatmap
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group, plus numeric clinical/phenotype columns
##  md$var: feature_id, optional compound_name, pvalue
##  params: trait_cols (character vector — names of md$obs numeric columns)
##          top_n (default 30), method ("spearman" | "pearson", default "spearman")
##          p_cut (default 0.05)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_metabolite_phenotype <- function(md, params) {
  library(ComplexHeatmap)
  library(circlize)

  X   <- md$X
  obs <- md$obs
  var <- md$var

  method <- if (!is.null(params$method)) params$method else "spearman"
  top_n  <- if (!is.null(params$top_n))  params$top_n  else 30
  p_cut  <- if (!is.null(params$p_cut))  params$p_cut  else 0.05

  # Identify trait columns
  trait_cols <- params$trait_cols
  if (is.null(trait_cols)) {
    fixed_cols <- c("sample_id", "group", "batch", "sample_type")
    trait_cols <- colnames(obs)[sapply(obs, is.numeric) & !colnames(obs) %in% fixed_cols]
  }
  trait_cols <- intersect(trait_cols, colnames(obs))

  if (length(trait_cols) == 0) {
    return(.placeholder_plot(
      "metabolite_phenotype: no numeric trait columns found in md$obs\nProvide params$trait_cols"
    ))
  }

  # Select top features
  if (!is.null(var$pvalue) && any(!is.na(var$pvalue))) {
    ord <- order(var$pvalue, na.last = TRUE)
  } else {
    ord <- order(apply(X, 2, var, na.rm = TRUE), decreasing = TRUE)
  }
  sel_idx <- ord[seq_len(min(top_n, ncol(X)))]
  X_sub   <- X[, sel_idx, drop = FALSE]
  var_sub <- var[sel_idx, , drop = FALSE]

  trait_mat <- as.matrix(obs[, trait_cols, drop = FALSE])
  trait_mat <- apply(trait_mat, 2, as.numeric)

  n_feat  <- ncol(X_sub)
  n_trait <- length(trait_cols)

  cor_mat <- matrix(NA_real_, nrow = n_feat, ncol = n_trait,
                     dimnames = list(colnames(X_sub), trait_cols))
  p_mat   <- cor_mat

  for (i in seq_len(n_feat)) {
    for (j in seq_len(n_trait)) {
      x_vec <- X_sub[, i]
      y_vec <- trait_mat[, j]
      valid <- !is.na(x_vec) & !is.na(y_vec)
      if (sum(valid) < 5) next
      ct <- tryCatch(
        cor.test(x_vec[valid], y_vec[valid], method = method),
        error = function(e) NULL
      )
      if (!is.null(ct)) {
        cor_mat[i, j] <- ct$estimate
        p_mat[i, j]   <- ct$p.value
      }
    }
  }

  # Remove all-NA rows
  keep_rows <- rowSums(!is.na(cor_mat)) > 0
  cor_mat   <- cor_mat[keep_rows, , drop = FALSE]
  p_mat     <- p_mat[keep_rows, , drop = FALSE]
  var_sub   <- var_sub[keep_rows, , drop = FALSE]

  if (nrow(cor_mat) == 0) {
    return(.placeholder_plot("All correlations failed — insufficient data"))
  }

  # Row labels
  row_labels <- if (!is.null(var_sub$compound_name) && any(!is.na(var_sub$compound_name))) {
    ifelse(is.na(var_sub$compound_name), var_sub$feature_id, var_sub$compound_name)
  } else { var_sub$feature_id }

  # Significance stars
  sig_stars <- matrix(
    ifelse(is.na(p_mat), "",
           ifelse(p_mat < 0.001, "***",
                  ifelse(p_mat < 0.01, "**",
                         ifelse(p_mat < p_cut, "*", "")))),
    nrow = nrow(p_mat)
  )

  col_fun <- colorRamp2(c(-1, 0, 1),
                         c(mf_colors$down, "white", mf_colors$up))

  Heatmap(
    cor_mat,
    name             = sprintf("%s r", tools::toTitleCase(method)),
    col              = col_fun,
    cell_fun         = function(j, i, x, y, width, height, fill) {
      if (sig_stars[i, j] != "") {
        grid::grid.text(sig_stars[i, j], x, y,
                         gp = grid::gpar(fontsize = 8, col = "grey20"))
      }
    },
    show_row_names   = TRUE,
    row_labels       = row_labels,
    row_names_gp     = gpar(fontsize = 7),
    column_names_gp  = gpar(fontsize = 9),
    cluster_rows     = TRUE,
    cluster_columns  = TRUE,
    clustering_distance_rows    = "euclidean",
    clustering_distance_columns = "euclidean",
    column_title     = sprintf("Metabolite–Phenotype Correlation (%s)", tools::toTitleCase(method)),
    column_title_gp  = gpar(fontsize = 11, fontface = "bold"),
    heatmap_legend_param = list(title_gp = gpar(fontsize = 9),
                                 labels_gp = gpar(fontsize = 8))
  )
}

##############################################################################
##  templates/advanced/mfuzz_temporal.R
##  A05 — Mfuzz temporal clustering line plots
##
##  md$X  : samples × features matrix (columns are time points or ordered groups)
##  md$obs: sample_id, group (used as time axis — levels define order)
##  params: n_clusters (default 6), min_membership (default 0.5)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_mfuzz_temporal <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  if (!requireNamespace("Mfuzz", quietly = TRUE) ||
      !requireNamespace("Biobase", quietly = TRUE)) {
    return(.placeholder_plot(
      "Mfuzz package required for temporal clustering\nInstall: BiocManager::install('Mfuzz')"
    ))
  }

  n_clusters     <- if (!is.null(params$n_clusters))     params$n_clusters     else 6
  min_membership <- if (!is.null(params$min_membership)) params$min_membership else 0.5

  X   <- md$X
  obs <- md$obs

  # Average by group to get per-timepoint mean
  groups    <- levels(factor(obs$group))
  time_mat  <- do.call(rbind, lapply(groups, function(g) {
    rows <- obs$group == g
    colMeans(X[rows, , drop = FALSE], na.rm = TRUE)
  }))
  rownames(time_mat) <- groups

  # features × timepoints for Mfuzz (rows=features)
  feat_mat <- t(time_mat)
  feat_mat <- feat_mat[apply(feat_mat, 1, function(x) sum(is.na(x)) < ncol(feat_mat)), ]

  if (nrow(feat_mat) < n_clusters) {
    return(.placeholder_plot(
      sprintf("Too few features (%d) for %d clusters", nrow(feat_mat), n_clusters)
    ))
  }

  # Build ExpressionSet
  eset <- Biobase::ExpressionSet(assayData = feat_mat)
  eset <- Mfuzz::filter.NA(eset, thres = 0.25)
  eset <- Mfuzz::fill.NA(eset, mode = "mean")
  eset <- Mfuzz::standardise(eset)

  # Estimate fuzzifier m
  m_val <- tryCatch(Mfuzz::mestimate(eset), error = function(e) 1.25)

  # Cluster
  cl <- tryCatch(
    Mfuzz::mfuzz(eset, c = n_clusters, m = m_val),
    error = function(e) NULL
  )
  if (is.null(cl)) return(.placeholder_plot("Mfuzz clustering failed"))

  # Build plot data
  centers    <- cl$centers           # n_clusters × n_timepoints
  membership <- cl$membership        # n_features × n_clusters

  # Build long-format for individual traces (members with high membership)
  expr_mat <- Biobase::exprs(eset)   # features × timepoints

  plot_list <- lapply(seq_len(n_clusters), function(k) {
    mem_mask <- membership[, k] >= min_membership
    if (sum(mem_mask) == 0) return(NULL)

    # Individual traces
    traces <- as.data.frame(t(expr_mat[mem_mask, , drop = FALSE]))
    traces$time <- factor(groups, levels = groups)
    long_traces <- reshape(
      cbind(time = as.character(traces$time), traces[, -ncol(traces), drop = FALSE]),
      direction = "long",
      varying   = colnames(traces)[-ncol(traces)],
      v.names   = "expression",
      timevar   = "feature",
      times     = colnames(traces)[-ncol(traces)]
    )
    long_traces$time <- factor(long_traces$time, levels = groups)

    # Center line
    center_df <- data.frame(
      time       = factor(groups, levels = groups),
      expression = as.numeric(centers[k, ])
    )

    ggplot() +
      geom_line(data = long_traces, aes(x = time, y = expression, group = feature),
                color = "grey70", alpha = 0.4, linewidth = 0.4) +
      geom_line(data = center_df, aes(x = time, y = expression, group = 1),
                color = mf_discrete[((k - 1) %% length(mf_discrete)) + 1],
                linewidth = 1.5) +
      geom_point(data = center_df, aes(x = time, y = expression),
                 color = mf_discrete[((k - 1) %% length(mf_discrete)) + 1],
                 size = 2.5) +
      labs(title = sprintf("Cluster %d (n=%d)", k, sum(mem_mask)),
           x = "Time / Group", y = "Z-score") +
      theme_metaboflow() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))
  })

  # Remove empty clusters
  plot_list <- Filter(Negate(is.null), plot_list)
  if (length(plot_list) == 0) return(.placeholder_plot("No clusters with sufficient membership"))

  # Arrange in grid (up to 3 columns)
  n_cols <- min(3, length(plot_list))
  wrap_plots(plot_list, ncol = n_cols) +
    plot_annotation(
      title = sprintf("Mfuzz Temporal Clustering (c=%d, m=%.2f)", n_clusters, m_val)
    )
}

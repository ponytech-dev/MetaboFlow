##############################################################################
##  templates/advanced/rf_importance.R
##  A29 — Random forest feature importance
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group
##  md$var: feature_id, optional compound_name
##  params: top_n (default 20), n_trees (default 500),
##          importance_type: "MDA" | "MDG" (default "MDA" — mean decrease accuracy)
##          seed (default 42)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_rf_importance <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("randomForest", quietly = TRUE)) {
    return(.placeholder_plot(
      "randomForest package required\nInstall: install.packages('randomForest')"
    ))
  }

  X   <- md$X
  obs <- md$obs
  var <- md$var

  top_n           <- if (!is.null(params$top_n))           params$top_n           else 20
  n_trees         <- if (!is.null(params$n_trees))         params$n_trees         else 500
  importance_type <- if (!is.null(params$importance_type)) params$importance_type else "MDA"
  seed            <- if (!is.null(params$seed))            params$seed            else 42

  # Prepare data
  col_var <- apply(X, 2, var, na.rm = TRUE)
  X       <- X[, col_var > 0, drop = FALSE]

  # Impute NAs
  for (j in seq_len(ncol(X))) {
    nas <- is.na(X[, j])
    if (any(nas)) X[nas, j] <- mean(X[, j], na.rm = TRUE)
  }

  y <- factor(obs$group)

  if (length(levels(y)) < 2) {
    return(.placeholder_plot("rf_importance requires ≥2 groups in md$obs$group"))
  }

  # Fit RF
  set.seed(seed)
  rf_model <- tryCatch(
    randomForest::randomForest(
      x          = X,
      y          = y,
      ntree      = n_trees,
      importance = TRUE
    ),
    error = function(e) { message("RF error: ", e$message); NULL }
  )

  if (is.null(rf_model)) {
    return(.placeholder_plot("Random forest fitting failed"))
  }

  # Extract importance
  imp_mat  <- randomForest::importance(rf_model)
  imp_type <- if (importance_type == "MDA") {
    if ("MeanDecreaseAccuracy" %in% colnames(imp_mat)) "MeanDecreaseAccuracy"
    else colnames(imp_mat)[ncol(imp_mat) - 1]
  } else {
    if ("MeanDecreaseGini" %in% colnames(imp_mat)) "MeanDecreaseGini"
    else colnames(imp_mat)[ncol(imp_mat)]
  }

  imp_df <- data.frame(
    feature_id = rownames(imp_mat),
    importance = imp_mat[, imp_type],
    stringsAsFactors = FALSE
  )
  imp_df <- imp_df[order(imp_df$importance, decreasing = TRUE), ]
  imp_df <- head(imp_df, top_n)

  # Labels
  if (!is.null(var$compound_name)) {
    name_map <- setNames(var$compound_name, var$feature_id)
    imp_df$label <- ifelse(is.na(name_map[imp_df$feature_id]),
                            imp_df$feature_id,
                            name_map[imp_df$feature_id])
  } else {
    imp_df$label <- imp_df$feature_id
  }
  imp_df$label <- factor(imp_df$label, levels = rev(imp_df$label))

  # Add logFC coloring if available
  if (!is.null(var$logFC)) {
    fc_map      <- setNames(var$logFC, var$feature_id)
    imp_df$logFC <- fc_map[imp_df$feature_id]
    imp_df$direction <- ifelse(is.na(imp_df$logFC), "Unknown",
                                ifelse(imp_df$logFC > 0, "Up", "Down"))
  } else {
    imp_df$direction <- "Unknown"
  }

  dir_colors <- c(Up = mf_colors$up, Down = mf_colors$down,
                   Unknown = mf_colors$not_significant)
  present_dirs <- unique(imp_df$direction)

  # Model OOB error
  oob_error <- round(rf_model$err.rate[n_trees, "OOB"] * 100, 1)

  ggplot(imp_df, aes(x = importance, y = label, color = direction)) +
    geom_segment(aes(x = 0, xend = importance, y = label, yend = label),
                 linewidth = 0.8, alpha = 0.7) +
    geom_point(size = 4) +
    scale_color_manual(values = dir_colors[present_dirs], name = "Direction") +
    labs(
      title    = sprintf("Random Forest Feature Importance (Top %d)", nrow(imp_df)),
      subtitle = sprintf("OOB error: %.1f%%  |  metric: %s  |  trees: %d",
                          oob_error, imp_type, n_trees),
      x        = imp_type,
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(
      axis.text.y     = element_text(size = 7),
      legend.position = "right"
    )
}

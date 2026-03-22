##############################################################################
##  templates/advanced/roc_curve.R
##  A14 — ROC curve with AUC
##
##  md$X  : samples × features matrix
##  md$obs: sample_id, group (binary — 2 groups)
##  md$var: feature_id, optional compound_name, optional vip / logFC
##  params: feature_ids (character vector of features to plot, default: top 5 by |logFC|)
##          pos_class (default: first group alphabetically), ci (default FALSE)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_roc_curve <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("pROC", quietly = TRUE)) {
    return(.placeholder_plot(
      "pROC package required\nInstall: install.packages('pROC')"
    ))
  }

  X   <- md$X
  obs <- md$obs
  var <- md$var

  groups <- unique(obs$group)
  if (length(groups) != 2) {
    return(.placeholder_plot(
      sprintf("roc_curve requires exactly 2 groups in md$obs$group (found: %d)", length(groups))
    ))
  }

  pos_class <- if (!is.null(params$pos_class)) params$pos_class else sort(groups)[1]
  ci_flag   <- if (!is.null(params$ci))        params$ci        else FALSE

  # Select features to plot
  feature_ids <- params$feature_ids
  if (is.null(feature_ids)) {
    if (!is.null(var$logFC) && any(!is.na(var$logFC))) {
      top_idx     <- order(abs(var$logFC), decreasing = TRUE)[seq_len(min(5, ncol(X)))]
      feature_ids <- colnames(X)[top_idx]
    } else {
      feature_ids <- colnames(X)[seq_len(min(5, ncol(X)))]
    }
  }
  feature_ids <- intersect(feature_ids, colnames(X))
  if (length(feature_ids) == 0) {
    return(.placeholder_plot("No matching feature_ids found in md$X"))
  }

  response <- ifelse(obs$group == pos_class, 1, 0)

  # Compute ROC for each feature
  roc_list <- lapply(feature_ids, function(fid) {
    scores  <- X[, fid]
    valid   <- !is.na(scores) & !is.na(response)
    if (sum(valid) < 10) return(NULL)

    roc_obj <- tryCatch(
      pROC::roc(response[valid], scores[valid], direction = "auto", quiet = TRUE),
      error = function(e) NULL
    )
    if (is.null(roc_obj)) return(NULL)

    # Extract coords
    coords   <- pROC::coords(roc_obj, "all", ret = c("specificity", "sensitivity"))
    auc_val  <- as.numeric(pROC::auc(roc_obj))

    # Label
    cname <- if (!is.null(var$compound_name)) var$compound_name[match(fid, var$feature_id)] else NA
    label <- if (!is.na(cname)) cname else fid

    data.frame(
      fpr         = 1 - coords$specificity,
      tpr         = coords$sensitivity,
      feature     = sprintf("%s (AUC=%.3f)", label, auc_val),
      auc         = auc_val,
      stringsAsFactors = FALSE
    )
  })

  roc_list <- Filter(Negate(is.null), roc_list)
  if (length(roc_list) == 0) {
    return(.placeholder_plot("ROC calculation failed for all features"))
  }

  plot_df <- do.call(rbind, roc_list)

  # Sort legend by AUC descending
  auc_order   <- unique(plot_df[order(-plot_df$auc), "feature"])
  plot_df$feature <- factor(plot_df$feature, levels = auc_order)

  n_feat   <- length(unique(plot_df$feature))
  pal      <- setNames(
    mf_discrete[((seq_len(n_feat) - 1) %% length(mf_discrete)) + 1],
    levels(plot_df$feature)
  )

  ggplot(plot_df, aes(x = fpr, y = tpr, color = feature)) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey60") +
    geom_line(linewidth = 0.9) +
    scale_color_manual(values = pal, name = NULL) +
    scale_x_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
    scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
    labs(
      title    = "ROC Curves",
      subtitle = sprintf("Positive class: %s", pos_class),
      x        = "False Positive Rate (1 - Specificity)",
      y        = "True Positive Rate (Sensitivity)"
    ) +
    theme_metaboflow() +
    theme(legend.position = "right", legend.text = element_text(size = 8))
}

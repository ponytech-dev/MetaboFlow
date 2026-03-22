##############################################################################
##  templates/advanced/arc_diagram.R
##  A23 — Arc diagram for cross-contrast feature patterns
##
##  md$uns$contrasts: named list of contrast data.frames
##    each with: feature_id, logFC, pvalue
##  md$var: feature_id, optional compound_name
##  params: fc_cut (default 1), p_cut (default 0.05), top_n (default 20)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_arc_diagram <- function(md, params) {
  library(ggplot2)

  contrasts <- md$uns$contrasts
  if (is.null(contrasts) || length(contrasts) < 2) {
    return(.placeholder_plot(
      "arc_diagram requires md$uns$contrasts with ≥2 contrasts"
    ))
  }

  fc_cut <- if (!is.null(params$fc_cut)) params$fc_cut else 1
  p_cut  <- if (!is.null(params$p_cut))  params$p_cut  else 0.05
  top_n  <- if (!is.null(params$top_n))  params$top_n  else 20
  var    <- md$var

  ct_names <- names(contrasts)
  n_ct     <- length(ct_names)

  # Build wide matrix: features × contrasts with regulation direction
  all_fids <- unique(unlist(lapply(contrasts, function(ct) ct$feature_id)))

  reg_mat <- do.call(cbind, lapply(ct_names, function(cn) {
    ct <- contrasts[[cn]]
    reg <- ifelse(
      abs(ct$logFC) >= fc_cut & ct$pvalue <= p_cut,
      sign(ct$logFC),
      0
    )
    setNames(reg[match(all_fids, ct$feature_id)], all_fids)
  }))
  colnames(reg_mat) <- ct_names
  rownames(reg_mat) <- all_fids
  reg_mat[is.na(reg_mat)] <- 0

  # Select features significant in ≥1 contrast
  n_sig <- rowSums(reg_mat != 0)
  sig_fids <- names(n_sig[n_sig > 0])

  if (length(sig_fids) == 0) {
    return(.placeholder_plot("No significant features across contrasts"))
  }

  # Rank: consistent direction (concordant) ranked higher
  concordance <- apply(reg_mat[sig_fids, , drop = FALSE], 1, function(r) {
    r <- r[r != 0]
    if (length(r) == 0) return(0)
    abs(sum(r)) / length(r)
  })
  top_fids <- names(sort(concordance, decreasing = TRUE))[seq_len(min(top_n, length(sig_fids)))]

  # Build arc data
  # Features arranged on x-axis, contrasts as y-levels
  feat_order   <- rev(top_fids)
  feat_x       <- setNames(seq_along(feat_order), feat_order)

  # Labels
  if (!is.null(var$compound_name)) {
    name_map <- setNames(var$compound_name, var$feature_id)
    feat_labels <- ifelse(is.na(name_map[feat_order]), feat_order, name_map[feat_order])
  } else {
    feat_labels <- feat_order
  }

  # Point data: one row per (feature, contrast)
  point_df <- do.call(rbind, lapply(ct_names, function(cn) {
    y_pos <- which(ct_names == cn)
    data.frame(
      x          = feat_x[top_fids],
      y          = y_pos,
      contrast   = cn,
      feature_id = top_fids,
      direction  = reg_mat[top_fids, cn],
      stringsAsFactors = FALSE
    )
  }))
  point_df$direction_f <- factor(
    ifelse(point_df$direction == 1, "Up",
           ifelse(point_df$direction == -1, "Down", "NS")),
    levels = c("Up", "Down", "NS")
  )

  # Arc data: connect same feature across contrasts where significant
  arc_df <- do.call(rbind, lapply(top_fids, function(fid) {
    sig_cts <- ct_names[reg_mat[fid, ] != 0]
    if (length(sig_cts) < 2) return(NULL)
    combn(sig_cts, 2, function(pair) {
      y1 <- which(ct_names == pair[1])
      y2 <- which(ct_names == pair[2])
      data.frame(x = feat_x[fid], y1 = y1, y2 = y2,
                 fid = fid, same_dir = reg_mat[fid, pair[1]] == reg_mat[fid, pair[2]],
                 stringsAsFactors = FALSE)
    }, simplify = FALSE) |> do.call(what = rbind)
  }))

  p <- ggplot() +
    # Arcs via geom_curve
    { if (!is.null(arc_df) && nrow(arc_df) > 0)
      geom_curve(data = arc_df,
                  aes(x = x, xend = x, y = y1, yend = y2, color = same_dir),
                  curvature = 0.4, linewidth = 0.7, alpha = 0.5)
    } +
    geom_point(data = point_df[point_df$direction_f != "NS", ],
               aes(x = x, y = y, shape = direction_f, color = direction_f),
               size = 3.5) +
    geom_point(data = point_df[point_df$direction_f == "NS", ],
               aes(x = x, y = y), shape = 1, size = 2,
               color = mf_colors$not_significant) +
    scale_color_manual(
      values = c("TRUE" = "#4DBBD5", "FALSE" = "#F39B7F",
                  "Up" = mf_colors$up, "Down" = mf_colors$down, "NS" = mf_colors$not_significant),
      name = NULL, guide = "none"
    ) +
    scale_shape_manual(values = c("Up" = 24, "Down" = 25, "NS" = 1), name = "Direction") +
    scale_x_continuous(breaks = seq_along(feat_order), labels = feat_labels) +
    scale_y_continuous(breaks = seq_along(ct_names), labels = ct_names,
                        limits = c(0.5, n_ct + 0.5)) +
    labs(
      title    = "Arc Diagram — Cross-Contrast Feature Patterns",
      subtitle = sprintf("Top %d features | Blue arcs = concordant", length(top_fids)),
      x        = NULL, y = "Contrast"
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, size = 6),
      panel.grid.major.x = element_line(color = "grey92")
    )

  p
}

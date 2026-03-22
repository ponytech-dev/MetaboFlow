##############################################################################
##  templates/advanced/contour_scatter.R
##  A24 — Contour scatter (mz-RT density + annotation overlay)
##
##  md$var: feature_id, mz, rt, optional compound_name, schymanski_level,
##          annotated (logical), logFC
##  params: annotated_only_overlay (default FALSE — show all, highlight annotated)
##          contour_bins (default 12), label_top_n (default 20)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_contour_scatter <- function(md, params) {
  library(ggplot2)
  library(ggrepel)

  var <- md$var
  if (is.null(var$mz) || is.null(var$rt)) {
    return(.placeholder_plot("contour_scatter requires md$var$mz and md$var$rt"))
  }

  contour_bins <- if (!is.null(params$contour_bins)) params$contour_bins else 12
  label_top_n  <- if (!is.null(params$label_top_n))  params$label_top_n  else 20

  df <- var[!is.na(var$mz) & !is.na(var$rt), ]

  # Annotated flag
  if (!is.null(df$annotated)) {
    df$is_annotated <- df$annotated
  } else if (!is.null(df$compound_name)) {
    df$is_annotated <- !is.na(df$compound_name)
  } else {
    df$is_annotated <- FALSE
  }

  # Color for overlay points
  if (!is.null(df$schymanski_level)) {
    level_colors <- c(
      "1" = mf_colors$up, "2" = "#F39B7F",
      "3" = "#4DBBD5",    "4" = mf_colors$down,
      "5" = "#7E6148",    "NA" = mf_colors$not_significant
    )
    df$level_str  <- ifelse(is.na(df$schymanski_level), "NA",
                             as.character(df$schymanski_level))
    df$point_color <- level_colors[df$level_str]
    df$point_color[is.na(df$point_color)] <- mf_colors$not_significant
    color_title <- "Schymanski Level"
    anno_df     <- df[df$is_annotated, ]
  } else if (!is.null(df$logFC)) {
    df$point_color  <- NULL   # use gradient
    color_title     <- "log2FC"
    anno_df         <- df[df$is_annotated, ]
  } else {
    df$point_color   <- mf_colors$up
    color_title      <- NULL
    anno_df          <- df[df$is_annotated, ]
  }

  # Labels: top_n annotated by |logFC| or by mz
  if (nrow(anno_df) > 0 && !is.null(anno_df$compound_name)) {
    if (!is.null(anno_df$logFC)) {
      label_idx <- order(abs(anno_df$logFC), decreasing = TRUE)[seq_len(min(label_top_n, nrow(anno_df)))]
    } else {
      label_idx <- seq_len(min(label_top_n, nrow(anno_df)))
    }
    anno_df$label <- ifelse(is.na(anno_df$compound_name),
                             anno_df$feature_id, anno_df$compound_name)
    label_df <- anno_df[label_idx, ]
  } else {
    label_df <- data.frame()
  }

  p <- ggplot(df, aes(x = rt, y = mz)) +
    # Density contours
    stat_density_2d(aes(fill = after_stat(density)), geom = "raster",
                    contour = FALSE, alpha = 0.6) +
    scale_fill_gradientn(
      colors = c("white", "#91D1C2", "#4DBBD5", "#3C5488"),
      name = "Density"
    ) +
    stat_density_2d(color = "grey40", alpha = 0.4, bins = contour_bins, linewidth = 0.3) +
    # All features as small dots
    geom_point(size = 0.8, alpha = 0.3, color = "grey50") +
    # Annotated overlay
    { if (nrow(anno_df) > 0 && !is.null(anno_df$schymanski_level))
      geom_point(data = anno_df, aes(color = level_str), size = 2.5, alpha = 0.85)
    } +
    { if (nrow(anno_df) > 0 && is.null(anno_df$schymanski_level) && !is.null(anno_df$logFC))
      geom_point(data = anno_df, aes(color = logFC), size = 2.5, alpha = 0.85)
    } +
    # Labels
    { if (nrow(label_df) > 0)
      geom_text_repel(data = label_df, aes(label = label),
                       size = 2.5, max.overlaps = 20,
                       segment.color = "grey60", segment.size = 0.3,
                       color = "grey20")
    } +
    labs(
      title    = "m/z – RT Feature Map with Annotation Overlay",
      subtitle = sprintf("Total features: %d  |  Annotated: %d",
                          nrow(df), sum(df$is_annotated)),
      x        = "Retention Time (min)",
      y        = "m/z"
    ) +
    theme_metaboflow() +
    theme(legend.position = "right")

  # Add Schymanski color scale if applicable
  if (!is.null(df$schymanski_level)) {
    present_lvls <- unique(df$level_str)
    lc <- c("1" = mf_colors$up, "2" = "#F39B7F", "3" = "#4DBBD5",
             "4" = mf_colors$down, "5" = "#7E6148", "NA" = mf_colors$not_significant)
    p <- p + scale_color_manual(values = lc[present_lvls], name = color_title, na.value = "grey50")
  } else if (!is.null(df$logFC)) {
    p <- p + scale_color_gradient2(low = mf_colors$down, mid = "white", high = mf_colors$up,
                                    midpoint = 0, name = color_title)
  }

  p
}

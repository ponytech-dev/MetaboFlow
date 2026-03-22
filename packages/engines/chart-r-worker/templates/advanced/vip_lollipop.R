##############################################################################
##  templates/advanced/vip_lollipop.R
##  A03 — VIP score lollipop chart with FC direction coloring
##
##  md$var: feature_id, optional compound_name, logFC
##          vip column name set via params$vip_col (default "vip")
##  params: top_n (default 20), vip_col (default "vip"), vip_cut (default 1)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_vip_lollipop <- function(md, params) {
  library(ggplot2)

  var     <- md$var
  top_n   <- if (!is.null(params$top_n))   params$top_n   else 20
  vip_col <- if (!is.null(params$vip_col)) params$vip_col else "vip"
  vip_cut <- if (!is.null(params$vip_cut)) params$vip_cut else 1.0

  if (is.null(var[[vip_col]])) {
    return(.placeholder_plot(
      sprintf("vip_lollipop: column '%s' not found in md$var\nRun OPLS-DA / PLS-DA first", vip_col)
    ))
  }

  df         <- var
  df$vip_val <- df[[vip_col]]

  # Use compound name where available
  df$label <- if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    ifelse(is.na(df$compound_name), df$feature_id, df$compound_name)
  } else {
    df$feature_id
  }

  # Rank and subset
  df <- df[!is.na(df$vip_val), ]
  df <- df[order(df$vip_val, decreasing = TRUE), ]
  df <- head(df, top_n)
  df$label <- factor(df$label, levels = rev(df$label))

  # FC direction coloring
  if (!is.null(df$logFC) && any(!is.na(df$logFC))) {
    df$direction <- ifelse(is.na(df$logFC), "Unknown",
                           ifelse(df$logFC > 0, "Up", "Down"))
  } else {
    df$direction <- "Unknown"
  }

  dir_colors <- c(
    Up      = mf_colors$up,
    Down    = mf_colors$down,
    Unknown = mf_colors$not_significant
  )
  present_dirs <- unique(df$direction)

  ggplot(df, aes(x = vip_val, y = label, color = direction)) +
    geom_segment(aes(x = 0, xend = vip_val, y = label, yend = label),
                 linewidth = 0.8, alpha = 0.7) +
    geom_point(size = 4) +
    geom_vline(xintercept = vip_cut, linetype = "dashed",
               color = "grey40", linewidth = 0.6) +
    scale_color_manual(values = dir_colors[present_dirs], name = "Direction") +
    annotate("text", x = vip_cut + 0.05, y = 0.5,
             label = paste0("VIP = ", vip_cut), color = "grey40",
             size = 3, hjust = 0, vjust = 0) +
    labs(
      title    = sprintf("Top %d Features by VIP Score", min(top_n, nrow(df))),
      subtitle = "Color indicates fold-change direction",
      x        = "VIP Score",
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(
      axis.text.y = element_text(size = 8),
      legend.position = "right"
    )
}

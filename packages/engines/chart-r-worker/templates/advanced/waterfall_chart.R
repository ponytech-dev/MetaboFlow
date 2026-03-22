##############################################################################
##  templates/advanced/waterfall_chart.R
##  A11 — Waterfall chart of annotation scores (Schymanski level coloring)
##
##  md$var: feature_id, optional compound_name, allscore (or total_score),
##          schymanski_level
##  params: top_n (default 40), score_col (default "allscore")
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_waterfall_chart <- function(md, params) {
  library(ggplot2)

  var       <- md$var
  top_n     <- if (!is.null(params$top_n))     params$top_n     else 40
  score_col <- if (!is.null(params$score_col)) params$score_col else "allscore"

  if (is.null(var[[score_col]])) {
    # Try fallback column names
    fallbacks <- c("allscore", "total_score", "score", "ms2score")
    found     <- fallbacks[sapply(fallbacks, function(c) !is.null(var[[c]]))]
    if (length(found) > 0) {
      score_col <- found[1]
      warning(sprintf("waterfall_chart: using '%s' as score column", score_col))
    } else {
      return(.placeholder_plot(
        sprintf("waterfall_chart: column '%s' not found in md$var\nAvailable: %s",
                score_col, paste(colnames(var), collapse = ", "))
      ))
    }
  }

  df         <- var[!is.na(var[[score_col]]), ]
  df$score   <- df[[score_col]]
  df         <- df[order(df$score, decreasing = TRUE), ]
  df         <- head(df, top_n)
  df$rank    <- seq_len(nrow(df))

  # Labels
  df$label <- if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    ifelse(is.na(df$compound_name), df$feature_id, df$compound_name)
  } else { df$feature_id }

  # Schymanski level
  level_colors <- c(
    "1" = mf_colors$up,
    "2" = "#F39B7F",
    "3" = "#4DBBD5",
    "4" = mf_colors$down,
    "5" = "#7E6148",
    "NA" = mf_colors$not_significant
  )

  if (!is.null(df$schymanski_level)) {
    df$level_str <- as.character(df$schymanski_level)
    df$level_str[is.na(df$level_str)] <- "NA"
    df$level_label <- paste0("Level ", df$level_str)
    df$level_label[df$level_str == "NA"] <- "Unclassified"
  } else {
    df$level_str   <- "NA"
    df$level_label <- "Unclassified"
  }

  present_levels <- unique(df$level_str)
  bar_colors     <- setNames(
    level_colors[present_levels],
    paste0(ifelse(present_levels == "NA", "Unclassified", paste0("Level ", present_levels)))
  )

  ggplot(df, aes(x = rank, y = score, fill = level_label)) +
    geom_col(width = 0.85, alpha = 0.9) +
    scale_fill_manual(values = bar_colors, name = "Schymanski Level") +
    geom_text(aes(label = label), angle = 90, hjust = -0.1,
              size = 2.2, color = "grey20") +
    scale_x_continuous(breaks = df$rank, labels = df$rank) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
    labs(
      title    = sprintf("Annotation Score Waterfall (Top %d)", nrow(df)),
      subtitle = sprintf("Score column: %s", score_col),
      x        = "Rank",
      y        = "Annotation Score"
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x  = element_text(size = 6),
      legend.position = "right"
    )
}

##############################################################################
##  templates/advanced/parallel_coords.R
##  A17 — Parallel coordinates for multi-score visualization
##
##  md$var: feature_id, compound_name (optional),
##          ms1score, ms2score, isoscore, rtscore, adductscore (any subset),
##          schymanski_level (for coloring)
##  params: top_n (default 30), score_cols (character vector, default auto-detect)
##          color_by: "schymanski_level" | "ms2score" (default "schymanski_level")
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_parallel_coords <- function(md, params) {
  library(ggplot2)

  var    <- md$var
  top_n  <- if (!is.null(params$top_n))  params$top_n  else 30
  color_by <- if (!is.null(params$color_by)) params$color_by else "schymanski_level"

  # Auto-detect score columns
  default_score_cols <- c("ms1score", "ms2score", "isoscore", "rtscore", "adductscore")
  score_cols <- if (!is.null(params$score_cols)) {
    params$score_cols
  } else {
    default_score_cols[default_score_cols %in% colnames(var)]
  }

  if (length(score_cols) < 2) {
    return(.placeholder_plot(
      sprintf("parallel_coords requires ≥2 score columns\nAvailable: %s",
              paste(colnames(var), collapse = ", "))
    ))
  }

  # Select features
  df <- var[rowSums(!is.na(var[, score_cols, drop = FALSE])) == length(score_cols), ]
  if (nrow(df) == 0) {
    return(.placeholder_plot("No features with all score columns populated"))
  }

  # Rank by sum of scores
  df$total_score <- rowSums(df[, score_cols, drop = FALSE], na.rm = TRUE)
  df <- df[order(df$total_score, decreasing = TRUE), ]
  df <- head(df, top_n)

  # Labels
  df$label <- if (!is.null(df$compound_name) && any(!is.na(df$compound_name))) {
    ifelse(is.na(df$compound_name), df$feature_id, df$compound_name)
  } else { df$feature_id }

  # Color variable
  if (color_by == "schymanski_level" && !is.null(df$schymanski_level)) {
    df$color_val <- factor(
      ifelse(is.na(df$schymanski_level), "NA", as.character(df$schymanski_level))
    )
    level_colors <- c("1" = mf_colors$up, "2" = "#F39B7F", "3" = "#4DBBD5",
                      "4" = mf_colors$down, "5" = "#7E6148", "NA" = mf_colors$not_significant)
    fill_vals <- level_colors[as.character(levels(df$color_val))]
    scale_obj <- scale_color_manual(values = fill_vals, name = "Schymanski Level",
                                    na.value = mf_colors$not_significant)
  } else if (color_by %in% score_cols) {
    df$color_val <- df[[color_by]]
    scale_obj    <- scale_color_gradient(low = mf_colors$down, high = mf_colors$up,
                                          name = color_by)
  } else {
    df$color_val <- factor(seq_len(nrow(df)))
    n_f   <- nrow(df)
    pal   <- mf_discrete[((seq_len(n_f) - 1) %% length(mf_discrete)) + 1]
    scale_obj <- scale_color_manual(values = pal, guide = "none")
  }

  # Normalize scores to 0–1 for parallel axes
  norm_df <- df
  for (sc in score_cols) {
    rng <- range(norm_df[[sc]], na.rm = TRUE)
    if (diff(rng) > 0) {
      norm_df[[sc]] <- (norm_df[[sc]] - rng[1]) / diff(rng)
    }
  }

  # Melt to long format
  long_df <- reshape(
    norm_df[, c("label", score_cols, "color_val")],
    direction = "long",
    varying   = score_cols,
    v.names   = "score",
    timevar   = "axis",
    times     = score_cols,
    idvar     = "label"
  )
  long_df$axis <- factor(long_df$axis, levels = score_cols)

  ggplot(long_df, aes(x = axis, y = score, group = label, color = color_val)) +
    geom_line(alpha = 0.55, linewidth = 0.6) +
    geom_point(size = 1.8, alpha = 0.7) +
    scale_obj +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent_format()) +
    labs(
      title    = sprintf("Parallel Coordinates — Top %d Features", nrow(df)),
      subtitle = "Scores normalized to 0–1",
      x        = "Score Dimension",
      y        = "Normalized Score"
    ) +
    theme_metaboflow() +
    theme(
      axis.text.x = element_text(angle = 30, hjust = 1),
      legend.position = "right"
    )
}

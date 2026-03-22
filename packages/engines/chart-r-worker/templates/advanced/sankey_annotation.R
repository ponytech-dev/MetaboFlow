##############################################################################
##  templates/advanced/sankey_annotation.R
##  A16 — Sankey diagram of annotation pipeline flow
##
##  md$uns$annotation_summary: data.frame with columns:
##    stage (e.g. "Detected", "DB matched", "Level 1", "Level 2", "Level 3",
##            "Level 4/5", "Unannotated"), count
##  Or alternatively, md$var with schymanski_level column is auto-summarized.
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_sankey_annotation <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("ggalluvial", quietly = TRUE)) {
    return(.placeholder_plot(
      "ggalluvial package required\nInstall: install.packages('ggalluvial')"
    ))
  }
  library(ggalluvial)

  # Build summary from md$uns or md$var
  summary_df <- md$uns$annotation_summary

  if (is.null(summary_df)) {
    var <- md$var
    n_detected <- nrow(var)
    n_db_match <- sum(!is.na(var$compound_name))

    if (!is.null(var$schymanski_level)) {
      level_counts <- table(var$schymanski_level[!is.na(var$schymanski_level)])
    } else {
      level_counts <- c()
    }

    summary_df <- data.frame(
      stage = c(
        "Detected",
        "DB Matched",
        sprintf("Level %s", names(level_counts)),
        "Unannotated"
      ),
      count = c(
        n_detected,
        n_db_match,
        as.integer(level_counts),
        n_detected - n_db_match
      ),
      stringsAsFactors = FALSE
    )
  }

  if (is.null(summary_df) || nrow(summary_df) == 0) {
    return(.placeholder_plot("No annotation summary data available"))
  }

  # Build alluvial data: 3 axes — Features → Annotated/Not → Level
  var <- md$var

  # Build per-feature flow data
  if (!is.null(var)) {
    n     <- nrow(var)
    flow_df <- data.frame(
      feature_id = var$feature_id,
      detected   = "Detected",
      annotated  = ifelse(!is.na(var$compound_name), "DB Matched", "Unmatched"),
      level      = ifelse(
        !is.null(var$schymanski_level) & !is.na(var$schymanski_level),
        paste0("Level ", var$schymanski_level),
        "No Level"
      ),
      stringsAsFactors = FALSE
    )

    # Aggregate: count by flow combination
    agg_df <- as.data.frame(table(
      detected  = flow_df$detected,
      annotated = flow_df$annotated,
      level     = flow_df$level
    ))
    agg_df <- agg_df[agg_df$Freq > 0, ]
    colnames(agg_df)[colnames(agg_df) == "Freq"] <- "count"

    level_colors <- c(
      "Level 1"  = mf_colors$up,
      "Level 2"  = "#F39B7F",
      "Level 3"  = "#4DBBD5",
      "Level 4"  = mf_colors$down,
      "Level 5"  = "#7E6148",
      "No Level" = mf_colors$not_significant
    )
    present_levels <- unique(agg_df$level)
    fill_colors    <- level_colors[present_levels]
    fill_colors[is.na(fill_colors)] <- mf_colors$not_significant

    ggplot(agg_df,
           aes(axis1 = detected, axis2 = annotated, axis3 = level, y = count)) +
      geom_alluvium(aes(fill = level), width = 1/3, alpha = 0.7) +
      geom_stratum(width = 1/3, fill = "grey90", color = "grey50") +
      geom_label(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
      scale_fill_manual(values = fill_colors, name = "Level") +
      scale_x_discrete(limits = c("detected", "annotated", "level"),
                        labels = c("Features", "DB Match", "Conf. Level"),
                        expand = c(0.1, 0.1)) +
      labs(
        title    = "Annotation Pipeline Sankey",
        subtitle = sprintf("Total features: %d", nrow(var)),
        y        = "Feature Count"
      ) +
      theme_metaboflow() +
      theme(legend.position = "right")

  } else {
    # Simple bar fallback when md$var is absent
    summary_df$stage <- factor(summary_df$stage, levels = summary_df$stage)
    ggplot(summary_df, aes(x = stage, y = count, fill = stage)) +
      geom_col(alpha = 0.85) +
      scale_fill_manual(values = setNames(
        mf_discrete[seq_len(nrow(summary_df))], summary_df$stage), guide = "none") +
      labs(title = "Annotation Pipeline Summary", x = "Stage", y = "Feature Count") +
      theme_metaboflow() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  }
}

##############################################################################
##  templates/advanced/isotope_tracing.R
##  A27 — Stable isotope tracing flux plot (isotopologue distribution)
##
##  md$uns$isotopologue_data: data.frame with columns:
##    compound_name (or feature_id), label_number (0, 1, 2, ..., n),
##    sample_id (or group), fraction (0–1) or intensity
##  params: compounds (character vector, default: all unique)
##          color_by: "group" | "label" (default "group")
##          normalize (default TRUE — show mole fraction 0–1)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_isotope_tracing <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  iso_df <- md$uns$isotopologue_data
  if (is.null(iso_df)) {
    return(.placeholder_plot(
      "isotope_tracing requires md$uns$isotopologue_data\n(compound_name, label_number, group/sample_id, fraction/intensity)"
    ))
  }

  normalize <- if (!is.null(params$normalize)) params$normalize else TRUE
  color_by  <- if (!is.null(params$color_by))  params$color_by  else "group"

  # Identify compound column
  comp_col <- if ("compound_name" %in% colnames(iso_df)) "compound_name" else "feature_id"
  if (!comp_col %in% colnames(iso_df)) {
    return(.placeholder_plot("isotopologue_data needs 'compound_name' or 'feature_id' column"))
  }

  # Identify group/sample column
  grp_col <- if ("group" %in% colnames(iso_df)) "group" else "sample_id"

  # Identify value column
  val_col <- if ("fraction" %in% colnames(iso_df)) "fraction" else "intensity"

  compounds <- if (!is.null(params$compounds)) params$compounds else unique(iso_df[[comp_col]])
  iso_df    <- iso_df[iso_df[[comp_col]] %in% compounds, ]

  if (nrow(iso_df) == 0) {
    return(.placeholder_plot("No matching compounds in isotopologue_data"))
  }

  # Normalize per compound × sample to mole fraction
  if (normalize && val_col == "intensity") {
    iso_df$value <- iso_df[[val_col]]
    iso_df <- do.call(rbind, lapply(
      split(iso_df, list(iso_df[[comp_col]], iso_df[[grp_col]])),
      function(sub) {
        total <- sum(sub$value, na.rm = TRUE)
        sub$value <- if (total > 0) sub$value / total else sub$value
        sub
      }
    ))
  } else {
    iso_df$value <- iso_df[[val_col]]
  }

  # Aggregate by compound × group × label_number
  agg_df <- aggregate(
    value ~ get(comp_col) + get(grp_col) + label_number,
    data = iso_df,
    FUN  = function(x) c(mean = mean(x, na.rm = TRUE), se = sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x))))
  )
  colnames(agg_df)[1:3] <- c("compound", "group", "label_number")
  agg_df$mean_val <- agg_df$value[, "mean"]
  agg_df$se_val   <- agg_df$value[, "se"]
  agg_df$value    <- NULL

  # Build stacked bar per compound
  n_compounds <- length(unique(agg_df$compound))
  plot_list   <- lapply(unique(agg_df$compound), function(cpd) {
    sub <- agg_df[agg_df$compound == cpd, ]
    sub$label_f <- factor(paste0("M+", sub$label_number))
    sub$group   <- factor(sub$group)

    # Label isotopologue colors: M+0 grey, rest from palette
    n_labels  <- length(unique(sub$label_number))
    lbl_order <- paste0("M+", sort(unique(sub$label_number)))
    iso_colors <- setNames(
      c(mf_colors$not_significant,
        mf_discrete[seq_len(max(n_labels - 1, 0))])[seq_len(n_labels)],
      lbl_order
    )
    sub$label_f <- factor(paste0("M+", sub$label_number), levels = lbl_order)

    ggplot(sub, aes(x = group, y = mean_val, fill = label_f)) +
      geom_col(position = "stack", width = 0.7, alpha = 0.85) +
      scale_fill_manual(values = iso_colors, name = "Isotopologue") +
      scale_y_continuous(labels = if (normalize) scales::percent_format() else waiver(),
                          limits = c(0, if (normalize) 1.05 else NA)) +
      labs(title = cpd,
           x = NULL,
           y = if (normalize) "Mole Fraction" else "Intensity") +
      theme_metaboflow() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
            legend.position = if (n_compounds == 1) "right" else "none",
            plot.title = element_text(size = 9))
  })

  n_cols <- min(3, n_compounds)
  wrap_plots(plot_list, ncol = n_cols) +
    plot_annotation(
      title   = "Stable Isotope Tracing — Isotopologue Distribution",
      caption = sprintf("Compounds: %d  |  %s",
                        n_compounds, if (normalize) "Normalized to mole fraction" else "Raw intensities")
    )
}

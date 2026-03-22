##############################################################################
##  templates/advanced/isotope_verification.R
##  A12 — Isotope pattern verification (experimental vs theoretical)
##
##  md$uns$isotope_data: data.frame with columns:
##    feature_id, isotope (e.g. "M", "M+1", "M+2"), mz, intensity
##  md$var: feature_id, optional compound_name, formula, schymanski_level
##  params: feature_id (required — which feature to plot), max_features (default 4)
##          If feature_id is NULL, plots top max_features by intensity
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_isotope_verification <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  iso_data <- md$uns$isotope_data
  if (is.null(iso_data)) {
    return(.placeholder_plot(
      "isotope_verification requires md$uns$isotope_data\n(feature_id, isotope, mz, intensity)"
    ))
  }

  var          <- md$var
  target_fid   <- params$feature_id
  max_features <- if (!is.null(params$max_features)) params$max_features else 4

  # Select features to plot
  if (!is.null(target_fid)) {
    fids <- target_fid
  } else {
    # Auto-select: top features by total intensity
    total_int <- tapply(iso_data$intensity, iso_data$feature_id, sum, na.rm = TRUE)
    fids      <- names(sort(total_int, decreasing = TRUE))[seq_len(min(max_features, length(total_int)))]
  }

  plot_list <- lapply(fids, function(fid) {
    df <- iso_data[iso_data$feature_id == fid, ]
    if (nrow(df) == 0) return(NULL)

    # Normalize to 100%
    df$pct <- df$intensity / max(df$intensity, na.rm = TRUE) * 100
    df$source <- "Experimental"

    # Theoretical pattern (requires Rdisop; fall back to placeholder)
    formula_str <- if (!is.null(var$formula)) var$formula[match(fid, var$feature_id)] else NA
    theo_df     <- NULL

    if (!is.na(formula_str) && requireNamespace("Rdisop", quietly = TRUE)) {
      tryCatch({
        mol      <- Rdisop::getMolecule(formula_str)
        iso_vals <- mol$isotopes[[1]]
        # iso_vals: matrix with rows [mz, prob]
        theo_df  <- data.frame(
          isotope   = paste0("M+", seq_len(nrow(iso_vals)) - 1),
          mz        = iso_vals[, 1],
          intensity = iso_vals[, 2],
          source    = "Theoretical",
          stringsAsFactors = FALSE
        )
        theo_df$pct <- theo_df$intensity / max(theo_df$intensity) * 100
        theo_df     <- theo_df[theo_df$pct > 0.5, ]
      }, error = function(e) NULL)
    }

    # Combine
    combined <- if (!is.null(theo_df)) {
      rbind(df[, c("isotope", "mz", "intensity", "pct", "source")],
            theo_df[, c("isotope", "mz", "intensity", "pct", "source")])
    } else { df }

    combined$nudge_y <- ifelse(combined$source == "Experimental", 1, -1)

    # Compound label
    cname <- if (!is.null(var$compound_name)) var$compound_name[match(fid, var$feature_id)] else NA
    title_str <- if (!is.na(cname)) cname else fid

    ggplot(combined, aes(x = mz, y = pct * nudge_y, fill = source)) +
      geom_col(position = "identity", width = 0.008, alpha = 0.85) +
      geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
      scale_fill_manual(
        values = c("Experimental" = mf_colors$up, "Theoretical" = mf_colors$down),
        name = NULL
      ) +
      scale_y_continuous(
        labels = function(x) paste0(abs(x), "%"),
        breaks = pretty(c(-100, 100))
      ) +
      labs(title = title_str, x = "m/z", y = "Relative Intensity") +
      theme_metaboflow() +
      theme(legend.position = "bottom", plot.title = element_text(size = 9))
  })

  plot_list <- Filter(Negate(is.null), plot_list)
  if (length(plot_list) == 0) return(.placeholder_plot("No matching features found"))

  wrap_plots(plot_list, ncol = min(2, length(plot_list))) +
    plot_annotation(title = "Isotope Pattern Verification")
}

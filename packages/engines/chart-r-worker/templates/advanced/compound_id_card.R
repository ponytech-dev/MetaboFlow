##############################################################################
##  templates/advanced/compound_id_card.R
##  A13 — Compound identity card (multi-panel)
##
##  md$uns$id_card_data: list with:
##    $hit: data.frame (1 row) — feature_id, compound_name, formula, exact_mass,
##           mz_error_ppm, schymanski_level, ms2score, isoscore, ms1score,
##           adduct, smiles (optional)
##    $ms2_exp: data.frame — mz, intensity (experimental MS2)
##    $ms2_ref: data.frame — mz, intensity (reference MS2)
##  params: feature_id (selects from id_card_data if it's a list of hits)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

.score_gauge <- function(scores_df) {
  library(ggplot2)
  ggplot(scores_df, aes(x = score_name, y = value, fill = score_name)) +
    geom_col(width = 0.6, alpha = 0.85) +
    geom_text(aes(label = sprintf("%.3f", value)), vjust = -0.3, size = 3) +
    scale_fill_manual(values = setNames(mf_discrete[seq_len(nrow(scores_df))],
                                         scores_df$score_name)) +
    scale_y_continuous(limits = c(0, 1.1), breaks = c(0, 0.5, 1)) +
    labs(title = "Annotation Scores", x = NULL, y = "Score (0–1)") +
    theme_metaboflow() +
    theme(legend.position = "none", axis.text.x = element_text(size = 8))
}

render_compound_id_card <- function(md, params) {
  library(ggplot2)
  library(patchwork)

  id_data <- md$uns$id_card_data
  if (is.null(id_data)) {
    return(.placeholder_plot(
      "compound_id_card requires md$uns$id_card_data\n(list: $hit, $ms2_exp, $ms2_ref)"
    ))
  }

  hit     <- id_data$hit
  ms2_exp <- id_data$ms2_exp
  ms2_ref <- id_data$ms2_ref

  if (is.null(hit) || nrow(hit) == 0) {
    return(.placeholder_plot("id_card_data$hit is empty"))
  }
  hit <- hit[1, , drop = FALSE]

  # ---- Panel 1: Identity text card ----
  fields <- list(
    "Compound"       = if (!is.null(hit$compound_name)) hit$compound_name else "Unknown",
    "Feature ID"     = if (!is.null(hit$feature_id)) hit$feature_id else "—",
    "Formula"        = if (!is.null(hit$formula)) hit$formula else "—",
    "Exact Mass"     = if (!is.null(hit$exact_mass)) sprintf("%.4f Da", hit$exact_mass) else "—",
    "mz Error"       = if (!is.null(hit$mz_error_ppm)) sprintf("%.2f ppm", hit$mz_error_ppm) else "—",
    "Adduct"         = if (!is.null(hit$adduct)) hit$adduct else "—",
    "Confidence"     = if (!is.null(hit$schymanski_level))
                         sprintf("Schymanski Level %s", hit$schymanski_level) else "—"
  )

  txt_rows <- mapply(function(k, v) sprintf("%s:  %s", k, v),
                     names(fields), fields, SIMPLIFY = FALSE)
  card_text <- paste(txt_rows, collapse = "\n")

  p_card <- ggplot() +
    annotate("text", x = 0.05, y = 0.95, label = card_text,
             hjust = 0, vjust = 1, size = 3.2, family = "mono",
             color = "grey20") +
    labs(title = "Identity Summary") +
    theme_void() +
    theme(plot.title = element_text(size = 10, face = "bold"),
          panel.border = element_rect(fill = NA, color = "grey80"))

  # ---- Panel 2: Score gauge ----
  score_names <- c("ms1score", "ms2score", "isoscore", "rtscore", "adductscore")
  avail_scores <- score_names[score_names %in% colnames(hit)]
  if (length(avail_scores) > 0) {
    scores_df <- data.frame(
      score_name = avail_scores,
      value      = as.numeric(hit[1, avail_scores])
    )
    p_scores <- .score_gauge(scores_df)
  } else {
    p_scores <- .placeholder_plot("No score columns found\n(ms1score, ms2score, etc.)")
  }

  # ---- Panel 3: MS2 mirror ----
  if (!is.null(ms2_exp) && !is.null(ms2_ref) && nrow(ms2_exp) > 0 && nrow(ms2_ref) > 0) {
    ms2_exp$intensity <- ms2_exp$intensity / max(ms2_exp$intensity) * 100
    ms2_ref$intensity <- ms2_ref$intensity / max(ms2_ref$intensity) * 100
    ms2_exp$source    <- "Experimental"
    ms2_ref$intensity <- -ms2_ref$intensity
    ms2_ref$source    <- "Reference"

    ms2_combined <- rbind(ms2_exp, ms2_ref)
    max_mz <- max(ms2_combined$mz, na.rm = TRUE)

    p_ms2 <- ggplot(ms2_combined, aes(x = mz, yend = intensity, y = 0, color = source)) +
      geom_segment(linewidth = 0.8) +
      geom_hline(yintercept = 0, color = "grey40", linewidth = 0.5) +
      scale_color_manual(values = c("Experimental" = mf_colors$up,
                                     "Reference"     = mf_colors$down), name = NULL) +
      scale_y_continuous(labels = function(x) paste0(abs(x), "%")) +
      labs(title = "MS2 Mirror", x = "m/z", y = "Relative Intensity") +
      theme_metaboflow() +
      theme(legend.position = "bottom")
  } else {
    p_ms2 <- .placeholder_plot("MS2 data not available")
  }

  # ---- Panel 4: Structure (placeholder unless rcdk available) ----
  if (!is.null(hit$smiles) && !is.na(hit$smiles) && requireNamespace("rcdk", quietly = TRUE)) {
    mol <- tryCatch(rcdk::parse.smiles(as.character(hit$smiles))[[1]], error = function(e) NULL)
    if (!is.null(mol)) {
      img_file <- tempfile(fileext = ".png")
      tryCatch({
        rcdk::view.molecule.2d(mol, width = 200, height = 200, filename = img_file)
        img   <- png::readPNG(img_file)
        grob  <- grid::rasterGrob(img, interpolate = TRUE)
        p_struct <- ggplot() +
          annotation_custom(grob, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
          labs(title = "Structure") + theme_void()
      }, error = function(e) {
        p_struct <<- .placeholder_plot("Structure rendering failed")
      })
    } else {
      p_struct <- .placeholder_plot("SMILES parse failed")
    }
  } else {
    smiles_str <- if (!is.null(hit$smiles) && !is.na(hit$smiles))
      substr(as.character(hit$smiles), 1, 30)
    else "—"
    p_struct <- .placeholder_plot(
      if (is.null(hit$smiles) || is.na(hit$smiles))
        "No SMILES available"
      else
        paste0("rcdk required for structure\nSMILES: ", smiles_str)
    )
  }

  (p_card | p_scores) / (p_ms2 | p_struct) +
    plot_annotation(
      title = sprintf("Compound Identity Card: %s",
                      if (!is.null(hit$compound_name)) hit$compound_name else hit$feature_id)
    )
}

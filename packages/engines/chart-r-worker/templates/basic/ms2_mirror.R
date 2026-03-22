##############################################################################
##  templates/basic/ms2_mirror.R
##  MS2 mirror plot: experimental spectrum vs reference (mirrored below x-axis)
##
##  Data sources (tried in order):
##    1. md$uns$ms2_spectra[[feature_id]]  — pre-extracted MS2 data
##       Expected format: list with $experimental (data.frame: mz, intensity)
##                                  $reference    (data.frame: mz, intensity)
##    2. Fallback: placeholder message
##
##  params:
##    feature_id  (required) — which feature's MS2 to display
##    normalize   (default TRUE) — scale each spectrum to max 100
##    mz_range    (default NULL) — c(min, max) to zoom m/z axis
##    label_top_n (default 5) — annotate top-N peaks by intensity
##############################################################################

render_ms2_mirror <- function(md, params) {
  feature_id <- params$feature_id
  if (is.null(feature_id)) {
    return(.placeholder_plot(
      "ms2_mirror: params$feature_id is required\nSpecify which feature's MS2 spectrum to plot"
    ))
  }

  # ── Retrieve spectrum data ────────────────────────────────────────────────
  exp_spec <- NULL
  ref_spec <- NULL

  ms2_store <- md$uns$ms2_spectra
  if (!is.null(ms2_store) && !is.null(ms2_store[[feature_id]])) {
    entry    <- ms2_store[[feature_id]]
    exp_spec <- entry$experimental   # data.frame: mz, intensity
    ref_spec <- entry$reference      # data.frame: mz, intensity (optional)
  }

  if (is.null(exp_spec)) {
    # Try mzML-based extraction if mzml_dir is available
    if (!is.null(md$mzml_dir) && dir.exists(md$mzml_dir)) {
      return(.placeholder_plot(sprintf(
        "ms2_mirror: No pre-extracted MS2 for feature '%s'.\nmzml_dir is set — run MS2 extraction first and store in md$uns$ms2_spectra.",
        feature_id
      )))
    }
    return(.placeholder_plot(sprintf(
      "ms2_mirror: No MS2 data available for feature '%s'.\nPopulate md$uns$ms2_spectra[[feature_id]] with $experimental (and optionally $reference).",
      feature_id
    )))
  }

  normalize   <- if (!is.null(params$normalize))   isTRUE(params$normalize)       else TRUE
  label_top_n <- if (!is.null(params$label_top_n)) as.integer(params$label_top_n) else 5L
  mz_range    <- params$mz_range  # NULL or c(min, max)

  # ── Normalize intensities ─────────────────────────────────────────────────
  .norm <- function(df) {
    if (normalize && max(df$intensity, na.rm = TRUE) > 0) {
      df$intensity <- df$intensity / max(df$intensity, na.rm = TRUE) * 100
    }
    df
  }
  exp_spec <- .norm(exp_spec)
  has_ref  <- !is.null(ref_spec) && nrow(ref_spec) > 0
  if (has_ref) ref_spec <- .norm(ref_spec)

  # ── Build plot data ───────────────────────────────────────────────────────
  exp_df <- data.frame(
    mz        = exp_spec$mz,
    intensity =  exp_spec$intensity,   # positive — upper half
    spectrum  = "Experimental"
  )
  if (has_ref) {
    ref_df <- data.frame(
      mz        = ref_spec$mz,
      intensity = -ref_spec$intensity,  # negative — lower half (mirrored)
      spectrum  = "Reference"
    )
    all_df <- rbind(exp_df, ref_df)
  } else {
    all_df <- exp_df
  }

  # m/z filter
  if (!is.null(mz_range) && length(mz_range) == 2) {
    all_df <- all_df[all_df$mz >= mz_range[1] & all_df$mz <= mz_range[2], ]
  }

  # Top-N labels for experimental spectrum
  exp_top <- exp_df[order(exp_df$intensity, decreasing = TRUE)[seq_len(min(label_top_n, nrow(exp_df)))], ]
  if (!is.null(mz_range)) {
    exp_top <- exp_top[exp_top$mz >= mz_range[1] & exp_top$mz <= mz_range[2], ]
  }

  # Compound name from var table
  compound_name <- feature_id
  if (!is.null(md$var)) {
    idx <- which(md$var$feature_id == feature_id)
    if (length(idx) > 0 && !is.na(md$var$compound_name[idx[1]])) {
      compound_name <- md$var$compound_name[idx[1]]
    }
  }

  spectrum_colors <- c(
    Experimental = mf_colors$up,
    Reference    = mf_colors$down
  )

  p <- ggplot(all_df, aes(x = mz, y = intensity, color = spectrum)) +
    geom_segment(aes(xend = mz, yend = 0), linewidth = 0.8, alpha = 0.85) +
    geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
    scale_color_manual(values = spectrum_colors) +
    scale_y_continuous(
      labels = function(x) paste0(abs(x), "%"),
      name   = "Relative Intensity (%)"
    ) +
    labs(
      title    = sprintf("MS2 Mirror Plot — %s", compound_name),
      subtitle = if (has_ref) "Upper: Experimental | Lower: Reference (mirrored)" else "Experimental spectrum only",
      x        = "m/z",
      color    = NULL
    ) +
    theme_metaboflow()

  # Annotate top peaks
  if (nrow(exp_top) > 0) {
    p <- p + geom_text(
      data    = exp_top,
      mapping = aes(x = mz, y = intensity + 3, label = round(mz, 4)),
      size    = 2.5, color = mf_colors$up, inherit.aes = FALSE
    )
  }

  p
}

##############################################################################
##  templates/basic/eic_plot.R
##  Extracted Ion Chromatogram (EIC) for a specific m/z — class C
##
##  md$mzml_dir: path to directory containing .mzML files (required)
##  md$obs: sample_id, group, optionally file_name
##  md$var: optionally used to resolve feature_id → target_mz
##  params:
##    target_mz   (required) — m/z value to extract
##    ppm         (default 10) — mass tolerance in ppm
##    feature_id  (optional) — if provided, overrides target_mz lookup from md$var
##    max_samples (default 20)
##    ms_level    (default 1)
##    alpha       (default 0.7)
##    smooth      (default FALSE) — apply moving-average smoothing
##    smooth_n    (default 5)     — window size for smoothing
##############################################################################

render_eic_plot <- function(md, params) {
  # ── Resolve target m/z ───────────────────────────────────────────────────
  target_mz <- NULL

  if (!is.null(params$feature_id) && !is.null(md$var)) {
    idx <- which(md$var$feature_id == params$feature_id)
    if (length(idx) > 0) {
      target_mz <- md$var$mz[idx[1]]
    }
  }
  if (is.null(target_mz) && !is.null(params$target_mz)) {
    target_mz <- as.numeric(params$target_mz)
  }
  if (is.null(target_mz) || is.na(target_mz)) {
    return(.placeholder_plot(
      "eic_plot: params$target_mz is required (numeric m/z value)\nor provide params$feature_id matching md$var$feature_id"
    ))
  }

  # ── Guard: mzML directory ─────────────────────────────────────────────────
  mzml_dir <- md$mzml_dir
  if (is.null(mzml_dir) || !dir.exists(mzml_dir)) {
    return(.placeholder_plot(
      "eic_plot: md$mzml_dir is not set or directory does not exist.\nProvide a path to a folder containing .mzML files."
    ))
  }
  mzml_files <- list.files(mzml_dir, pattern = "\\.mzML$", full.names = TRUE, ignore.case = TRUE)
  if (length(mzml_files) == 0) {
    return(.placeholder_plot(sprintf("eic_plot: no .mzML files found in\n%s", mzml_dir)))
  }

  if (!requireNamespace("MSnbase", quietly = TRUE)) {
    return(.placeholder_plot(
      "eic_plot: MSnbase package is not installed.\nInstall with: BiocManager::install('MSnbase')"
    ))
  }

  ppm         <- if (!is.null(params$ppm))         as.numeric(params$ppm)         else 10
  max_samples <- if (!is.null(params$max_samples)) as.integer(params$max_samples) else 20L
  ms_level    <- if (!is.null(params$ms_level))    as.integer(params$ms_level)    else 1L
  alpha_val   <- if (!is.null(params$alpha))       as.numeric(params$alpha)       else 0.7
  do_smooth   <- if (!is.null(params$smooth))      isTRUE(params$smooth)          else FALSE
  smooth_n    <- if (!is.null(params$smooth_n))    as.integer(params$smooth_n)    else 5L

  mz_tol <- target_mz * ppm / 1e6
  mz_min <- target_mz - mz_tol
  mz_max <- target_mz + mz_tol

  obs <- md$obs
  if (!is.null(obs$file_name)) {
    file_map  <- setNames(mzml_files, basename(mzml_files))
    matched   <- file_map[obs$file_name]
    valid     <- !is.na(matched)
    obs_use   <- obs[valid, , drop = FALSE]
    files_use <- matched[valid]
  } else {
    stem_map  <- setNames(mzml_files, tools::file_path_sans_ext(basename(mzml_files)))
    matched   <- stem_map[obs$sample_id]
    valid     <- !is.na(matched)
    obs_use   <- obs[valid, , drop = FALSE]
    files_use <- matched[valid]
    if (sum(valid) == 0) {
      files_use <- mzml_files
      obs_use   <- data.frame(
        sample_id = tools::file_path_sans_ext(basename(mzml_files)),
        group     = "Unknown",
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(files_use) > max_samples) {
    files_use <- files_use[seq_len(max_samples)]
    obs_use   <- obs_use[seq_len(max_samples), , drop = FALSE]
  }

  # Simple moving-average helper
  .ma <- function(x, n) {
    if (length(x) < n) return(x)
    stats::filter(x, rep(1 / n, n), sides = 2)
  }

  eic_list <- lapply(seq_along(files_use), function(i) {
    tryCatch({
      raw <- MSnbase::readMSData(files_use[[i]], msLevel. = ms_level, mode = "onDisk")
      # Use filterMz to extract ion chromatogram in mass window
      raw_filt <- MSnbase::filterMz(raw, mz = c(mz_min, mz_max))
      hdr      <- MSnbase::header(raw_filt)
      intensity <- hdr$totIonCurrent
      if (do_smooth) intensity <- as.numeric(.ma(intensity, smooth_n))
      data.frame(
        rt        = hdr$retentionTime,
        intensity = intensity,
        sample_id = obs_use$sample_id[i],
        group     = if (!is.null(obs_use$group)) obs_use$group[i] else "Unknown",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      message(sprintf("eic_plot: failed to read %s — %s", basename(files_use[[i]]), e$message))
      NULL
    })
  })

  eic_df <- do.call(rbind, Filter(Negate(is.null), eic_list))
  if (is.null(eic_df) || nrow(eic_df) == 0) {
    return(.placeholder_plot("eic_plot: could not extract EIC from any mzML file"))
  }

  eic_df$group <- factor(eic_df$group)

  # Compound name for title if available
  compound_label <- if (!is.null(params$feature_id) && !is.null(md$var$compound_name)) {
    idx <- which(md$var$feature_id == params$feature_id)
    if (length(idx) > 0 && !is.na(md$var$compound_name[idx[1]])) {
      sprintf("%s (m/z %.4f ± %d ppm)", md$var$compound_name[idx[1]], target_mz, round(ppm))
    } else {
      sprintf("m/z %.4f ± %d ppm", target_mz, round(ppm))
    }
  } else {
    sprintf("m/z %.4f ± %d ppm", target_mz, round(ppm))
  }

  ggplot(eic_df, aes(x = rt / 60, y = intensity, group = sample_id, color = group)) +
    geom_line(alpha = alpha_val, linewidth = 0.6) +
    scale_color_metaboflow() +
    scale_y_continuous(labels = scales::scientific) +
    labs(
      title    = "Extracted Ion Chromatogram",
      subtitle = compound_label,
      x        = "Retention Time (min)",
      y        = "Ion Intensity",
      color    = "Group"
    ) +
    theme_metaboflow()
}

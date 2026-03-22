##############################################################################
##  templates/basic/bpc_comparison.R
##  Base Peak Chromatogram (BPC) comparison — class C, requires mzML files
##
##  Like TIC overlay but each scan plots the maximum intensity (base peak)
##  rather than total ion current.
##
##  md$mzml_dir: path to directory containing .mzML files (required)
##  md$obs: sample_id, group, optionally file_name
##  params:
##    max_samples (default 20)
##    alpha       (default 0.6)
##    ms_level    (default 1)
##    facet       (default FALSE) — separate panel per sample
##############################################################################

render_bpc_comparison <- function(md, params) {
  # ── Guard: mzML directory ─────────────────────────────────────────────────
  mzml_dir <- md$mzml_dir
  if (is.null(mzml_dir) || !dir.exists(mzml_dir)) {
    return(.placeholder_plot(
      "bpc_comparison: md$mzml_dir is not set or directory does not exist.\nProvide a path to a folder containing .mzML files."
    ))
  }
  mzml_files <- list.files(mzml_dir, pattern = "\\.mzML$", full.names = TRUE, ignore.case = TRUE)
  if (length(mzml_files) == 0) {
    return(.placeholder_plot(
      sprintf("bpc_comparison: no .mzML files found in\n%s", mzml_dir)
    ))
  }

  if (!requireNamespace("MSnbase", quietly = TRUE)) {
    return(.placeholder_plot(
      "bpc_comparison: MSnbase package is not installed.\nInstall with: BiocManager::install('MSnbase')"
    ))
  }

  max_samples <- if (!is.null(params$max_samples)) as.integer(params$max_samples) else 20L
  alpha_val   <- if (!is.null(params$alpha))       params$alpha                   else 0.6
  ms_level    <- if (!is.null(params$ms_level))    as.integer(params$ms_level)    else 1L
  do_facet    <- if (!is.null(params$facet))       isTRUE(params$facet)           else FALSE

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

  # ── Read BPC from each mzML file ─────────────────────────────────────────
  bpc_list <- lapply(seq_along(files_use), function(i) {
    tryCatch({
      raw <- MSnbase::readMSData(files_use[[i]], msLevel. = ms_level, mode = "onDisk")
      hdr <- MSnbase::header(raw)
      # basePeakIntensity is the maximum intensity per scan
      intensity_col <- if ("basePeakIntensity" %in% names(hdr)) {
        hdr$basePeakIntensity
      } else {
        # Fallback: compute from totIonCurrent (approximation)
        hdr$totIonCurrent
      }
      data.frame(
        rt        = hdr$retentionTime,
        intensity = intensity_col,
        sample_id = obs_use$sample_id[i],
        group     = if (!is.null(obs_use$group)) obs_use$group[i] else "Unknown",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      message(sprintf("bpc_comparison: failed to read %s — %s", basename(files_use[[i]]), e$message))
      NULL
    })
  })

  bpc_df <- do.call(rbind, Filter(Negate(is.null), bpc_list))
  if (is.null(bpc_df) || nrow(bpc_df) == 0) {
    return(.placeholder_plot("bpc_comparison: could not extract BPC from any mzML file"))
  }

  bpc_df$group <- factor(bpc_df$group)

  p <- ggplot(bpc_df, aes(x = rt / 60, y = intensity, group = sample_id, color = group)) +
    geom_line(alpha = alpha_val, linewidth = 0.5) +
    scale_color_metaboflow() +
    scale_y_continuous(labels = scales::scientific) +
    labs(
      title    = "Base Peak Chromatogram Comparison",
      subtitle = sprintf("%d samples | MS level %d", length(unique(bpc_df$sample_id)), ms_level),
      x        = "Retention Time (min)",
      y        = "Base Peak Intensity",
      color    = "Group"
    ) +
    theme_metaboflow()

  if (do_facet) {
    p <- p + facet_wrap(~ sample_id, scales = "free_y") +
      theme(legend.position = "none")
  }

  p
}

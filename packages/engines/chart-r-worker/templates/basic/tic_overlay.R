##############################################################################
##  templates/basic/tic_overlay.R
##  Total Ion Chromatogram (TIC) overlay — class C, requires mzML files
##
##  md$mzml_dir: path to directory containing .mzML files (required)
##  md$obs: sample_id, group, optionally file_name (basename of mzML)
##  params:
##    max_samples (default 20) — cap to avoid overplotting
##    alpha       (default 0.6) — line transparency
##    ms_level    (default 1)   — MS level to extract TIC from
##############################################################################

render_tic_overlay <- function(md, params) {
  # ── Guard: mzML directory ─────────────────────────────────────────────────
  mzml_dir <- md$mzml_dir
  if (is.null(mzml_dir) || !dir.exists(mzml_dir)) {
    return(.placeholder_plot(
      "tic_overlay: md$mzml_dir is not set or directory does not exist.\nProvide a path to a folder containing .mzML files."
    ))
  }
  mzml_files <- list.files(mzml_dir, pattern = "\\.mzML$", full.names = TRUE, ignore.case = TRUE)
  if (length(mzml_files) == 0) {
    return(.placeholder_plot(
      sprintf("tic_overlay: no .mzML files found in\n%s", mzml_dir)
    ))
  }

  # ── Dependencies ──────────────────────────────────────────────────────────
  if (!requireNamespace("MSnbase", quietly = TRUE)) {
    return(.placeholder_plot(
      "tic_overlay: MSnbase package is not installed.\nInstall with: BiocManager::install('MSnbase')"
    ))
  }

  max_samples <- if (!is.null(params$max_samples)) as.integer(params$max_samples) else 20L
  alpha_val   <- if (!is.null(params$alpha))       params$alpha                   else 0.6
  ms_level    <- if (!is.null(params$ms_level))    as.integer(params$ms_level)    else 1L

  # Match mzML files to sample metadata
  obs <- md$obs
  if (!is.null(obs$file_name)) {
    # obs$file_name contains basenames — match to full paths
    file_map <- setNames(mzml_files, basename(mzml_files))
    matched  <- file_map[obs$file_name]
    valid    <- !is.na(matched)
    obs_use  <- obs[valid, , drop = FALSE]
    files_use <- matched[valid]
  } else {
    # Match by sample_id to basename (strip extension)
    stem_map <- setNames(mzml_files, tools::file_path_sans_ext(basename(mzml_files)))
    matched  <- stem_map[obs$sample_id]
    valid    <- !is.na(matched)
    obs_use  <- obs[valid, , drop = FALSE]
    files_use <- matched[valid]
    if (sum(valid) == 0) {
      # Last resort: use all files in directory order
      files_use <- mzml_files
      obs_use   <- data.frame(
        sample_id = tools::file_path_sans_ext(basename(mzml_files)),
        group     = "Unknown",
        stringsAsFactors = FALSE
      )
    }
  }

  # Cap number of samples
  if (length(files_use) > max_samples) {
    files_use <- files_use[seq_len(max_samples)]
    obs_use   <- obs_use[seq_len(max_samples), , drop = FALSE]
  }

  # ── Read TIC from each mzML file ─────────────────────────────────────────
  tic_list <- lapply(seq_along(files_use), function(i) {
    tryCatch({
      raw <- MSnbase::readMSData(files_use[[i]], msLevel. = ms_level, mode = "onDisk")
      # Extract retention times and total ion counts per scan
      hdr <- MSnbase::header(raw)
      data.frame(
        rt        = hdr$retentionTime,
        intensity = hdr$totIonCurrent,
        sample_id = obs_use$sample_id[i],
        group     = if (!is.null(obs_use$group)) obs_use$group[i] else "Unknown",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      message(sprintf("tic_overlay: failed to read %s — %s", basename(files_use[[i]]), e$message))
      NULL
    })
  })

  tic_df <- do.call(rbind, Filter(Negate(is.null), tic_list))
  if (is.null(tic_df) || nrow(tic_df) == 0) {
    return(.placeholder_plot("tic_overlay: could not extract TIC from any mzML file"))
  }

  tic_df$group <- factor(tic_df$group)

  ggplot(tic_df, aes(x = rt / 60, y = intensity, group = sample_id, color = group)) +
    geom_line(alpha = alpha_val, linewidth = 0.5) +
    scale_color_metaboflow() +
    scale_y_continuous(labels = scales::scientific) +
    labs(
      title    = "TIC Overlay",
      subtitle = sprintf("%d samples | MS level %d", length(unique(tic_df$sample_id)), ms_level),
      x        = "Retention Time (min)",
      y        = "Total Ion Current",
      color    = "Group"
    ) +
    theme_metaboflow()
}

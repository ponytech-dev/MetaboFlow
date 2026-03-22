##############################################################################
##  templates/advanced/kegg_overlay.R
##  A07 — KEGG pathway overlay (pathview wrapper)
##
##  md$var: feature_id, logFC, optional kegg_id (KEGG compound ID e.g. "C00031")
##  md$uns$pathway_id: KEGG pathway ID string e.g. "hsa00010"
##  params: pathway_id (overrides md$uns), species (default "hsa"),
##          out_dir (default tempdir())
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_kegg_overlay <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("pathview", quietly = TRUE)) {
    return(.placeholder_plot(
      "pathview package required\nInstall: BiocManager::install('pathview')"
    ))
  }

  var <- md$var
  if (is.null(var$logFC)) {
    return(.placeholder_plot("kegg_overlay requires md$var$logFC"))
  }

  pathway_id <- if (!is.null(params$pathway_id)) params$pathway_id else md$uns$pathway_id
  if (is.null(pathway_id) || is.na(pathway_id)) {
    return(.placeholder_plot(
      "kegg_overlay requires pathway_id in params or md$uns$pathway_id\ne.g. 'hsa00010'"
    ))
  }

  species <- if (!is.null(params$species)) params$species else "hsa"
  out_dir <- if (!is.null(params$out_dir)) params$out_dir else tempdir()

  # Build named FC vector — kegg_id as names
  if (!is.null(var$kegg_id) && any(!is.na(var$kegg_id))) {
    mask    <- !is.na(var$kegg_id) & !is.na(var$logFC)
    fc_vec  <- setNames(var$logFC[mask], var$kegg_id[mask])
  } else {
    # Fallback: use feature_id (will only match if IDs are KEGG compound IDs)
    mask   <- !is.na(var$logFC)
    fc_vec <- setNames(var$logFC[mask], var$feature_id[mask])
    warning("kegg_overlay: md$var$kegg_id not found — using feature_id as KEGG IDs")
  }

  # pathview writes PNG to out_dir — we read and embed it
  old_wd <- getwd()
  setwd(out_dir)
  on.exit(setwd(old_wd), add = TRUE)

  result <- tryCatch(
    pathview::pathview(
      cpd.data   = fc_vec,
      pathway.id = pathway_id,
      species    = species,
      cpd.idtype = "kegg",
      out.suffix = "metaboflow",
      kegg.dir   = out_dir,
      same.layer = TRUE,
      low        = list(cpd = mf_colors$down),
      mid        = list(cpd = "white"),
      high       = list(cpd = mf_colors$up)
    ),
    error = function(e) { message("pathview error: ", e$message); NULL }
  )
  setwd(old_wd)

  if (is.null(result)) {
    return(.placeholder_plot(
      sprintf("pathview failed for pathway '%s'\nCheck internet connection and pathway ID", pathway_id)
    ))
  }

  # Locate generated PNG
  png_file <- file.path(out_dir, sprintf("%s.metaboflow.png", pathway_id))
  if (!file.exists(png_file)) {
    # Try alternative naming
    candidates <- list.files(out_dir, pattern = "\\.metaboflow\\.png$", full.names = TRUE)
    png_file   <- if (length(candidates) > 0) candidates[1] else NULL
  }

  if (!is.null(png_file) && file.exists(png_file)) {
    img <- png::readPNG(png_file)
    grid::grid.raster(img)
    # Return as grob wrapped in ggplot-compatible object for pipeline consistency
    grob <- grid::rasterGrob(img, interpolate = TRUE)
    ggplot() +
      annotation_custom(grob, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
      labs(title = sprintf("KEGG Pathway: %s", pathway_id)) +
      theme_void()
  } else {
    .placeholder_plot(sprintf("pathview ran but PNG not found\nPathway: %s", pathway_id))
  }
}

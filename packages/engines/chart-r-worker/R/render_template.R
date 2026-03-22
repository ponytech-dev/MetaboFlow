##############################################################################
##  chart-r-worker/R/render_template.R
##  Generic template dispatcher — renders any chart template to SVG + PDF + PNG
##
##  Each template file must define a function named render_{template_name}(md, params)
##  that returns a ggplot2 object (or ComplexHeatmap Heatmap).
##
##  Output formats:
##    SVG  — vector, for web display
##    PDF  — vector, publication submission (cairo_pdf for font embedding)
##    PNG  — 300 dpi raster, for reports
##
##  Dependencies: svglite, ggplot2, grDevices (base)
##############################################################################

render_template <- function(template_name, metabodata_path, output_dir,
                            mzml_dir = NULL, params = list()) {
  source("/app/R/metabodata_bridge.R")
  source("/app/R/metaboflow_theme.R")
  source("/app/R/color_palettes.R")

  # Locate template file (basic takes precedence over advanced if both exist)
  basic_path    <- file.path("/app/templates/basic",    paste0(template_name, ".R"))
  advanced_path <- file.path("/app/templates/advanced", paste0(template_name, ".R"))

  template_path <- if (file.exists(basic_path)) {
    basic_path
  } else if (file.exists(advanced_path)) {
    advanced_path
  } else {
    stop("Template not found: ", template_name)
  }

  # Source the template — it registers render_{name}(md, params)
  source(template_path)

  render_fn_name <- paste0("render_", template_name)
  if (!exists(render_fn_name, mode = "function")) {
    stop("Template must define function: ", render_fn_name)
  }
  render_fn <- get(render_fn_name)

  # Read MetaboData HDF5
  md <- read_metabodata(metabodata_path)
  if (!is.null(mzml_dir)) md$mzml_dir <- mzml_dir

  # Prepare output directory
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  base_path <- file.path(output_dir, template_name)

  width  <- if (!is.null(params$width))  params$width  else 10
  height <- if (!is.null(params$height)) params$height else 8

  # Render the plot object
  p <- render_fn(md, params)

  # --- SVG (vector, web display) ---
  svglite::svglite(paste0(base_path, ".svg"), width = width, height = height)
  print(p)
  dev.off()

  # --- PDF (vector, publication — cairo_pdf for font embedding) ---
  grDevices::cairo_pdf(paste0(base_path, ".pdf"), width = width, height = height)
  print(p)
  dev.off()

  # --- PNG (300 dpi raster, for reports) ---
  grDevices::png(paste0(base_path, ".png"),
                 width  = width  * 300,
                 height = height * 300,
                 res    = 300)
  print(p)
  dev.off()

  list(
    svg = paste0(base_path, ".svg"),
    pdf = paste0(base_path, ".pdf"),
    png = paste0(base_path, ".png")
  )
}

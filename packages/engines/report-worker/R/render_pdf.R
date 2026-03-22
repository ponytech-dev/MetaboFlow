render_pdf_report <- function(metabodata_path, chart_dir, output_dir,
                               selected_charts = NULL) {
  source("/app/R/metabodata_bridge.R")
  source("/app/R/methods_generator.R")

  md <- read_metabodata(metabodata_path)
  methods_text <- generate_methods(metabodata_path)

  # Gather chart PNGs
  if (is.null(selected_charts)) {
    chart_files <- list.files(chart_dir, pattern = "\\.png$", full.names = TRUE)
  } else {
    chart_files <- file.path(chart_dir, paste0(selected_charts, ".png"))
    chart_files <- chart_files[file.exists(chart_files)]
  }

  # Prepare data for Quarto template
  report_data <- list(
    n_samples = nrow(md$obs),
    n_features = ncol(md$X),
    n_significant = sum(md$var$significant, na.rm = TRUE),
    groups = paste(unique(md$obs$group), collapse = " vs "),
    methods_text = methods_text,
    chart_files = chart_files,
    obs = md$obs,
    var = md$var
  )

  # Write data as JSON for Quarto to read
  data_file <- file.path(output_dir, "report_data.json")
  jsonlite::write_json(report_data, data_file, auto_unbox = TRUE)

  # Copy template
  qmd_file <- file.path(output_dir, "report.qmd")
  file.copy("/app/templates/report.qmd", qmd_file, overwrite = TRUE)

  # Render with Quarto
  output_file <- file.path(output_dir, "report.pdf")
  system2("quarto", args = c("render", qmd_file, "--to", "pdf",
                               "--output", basename(output_file)),
          stdout = TRUE, stderr = TRUE)

  output_file
}

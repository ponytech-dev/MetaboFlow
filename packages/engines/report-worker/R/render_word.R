render_word_report <- function(metabodata_path, chart_dir, output_dir,
                                selected_charts = NULL) {
  library(officer)
  library(flextable)
  source("/app/R/metabodata_bridge.R")
  source("/app/R/methods_generator.R")

  md <- read_metabodata(metabodata_path)
  methods_text <- generate_methods(metabodata_path)

  # Create document
  doc <- read_docx()

  # Title
  doc <- body_add_par(doc, "MetaboFlow Analysis Report", style = "heading 1")
  doc <- body_add_par(doc, format(Sys.time(), "%Y-%m-%d %H:%M"), style = "Normal")

  # Section 1: Summary
  doc <- body_add_par(doc, "1. Analysis Summary", style = "heading 2")
  summary_df <- data.frame(
    Metric = c("Samples", "Features Detected", "Significant Features", "Groups"),
    Value = c(nrow(md$obs), ncol(md$X),
              sum(md$var$significant, na.rm = TRUE),
              paste(unique(md$obs$group), collapse = " vs "))
  )
  ft <- flextable(summary_df)
  ft <- autofit(ft)
  doc <- body_add_flextable(doc, ft)

  # Section 2: Charts
  doc <- body_add_par(doc, "2. Figures", style = "heading 2")
  if (is.null(selected_charts)) {
    chart_files <- list.files(chart_dir, pattern = "\\.png$", full.names = TRUE)
  } else {
    chart_files <- file.path(chart_dir, paste0(selected_charts, ".png"))
    chart_files <- chart_files[file.exists(chart_files)]
  }
  for (cf in chart_files) {
    chart_name <- tools::file_path_sans_ext(basename(cf))
    doc <- body_add_par(doc, paste("Figure:", chart_name), style = "heading 3")
    doc <- body_add_img(doc, src = cf, width = 6, height = 4.5)
    doc <- body_add_par(doc, "", style = "Normal")
  }

  # Section 3: Top Features Table
  doc <- body_add_par(doc, "3. Top Significant Features", style = "heading 2")
  if (!is.null(md$var$pvalue) && !is.null(md$var$logFC)) {
    sig <- md$var[md$var$significant == TRUE, , drop = FALSE]
    if (nrow(sig) > 0) {
      top <- head(sig[order(sig$pvalue), ], 20)
      cols <- intersect(c("feature_id", "mz", "rt", "logFC", "pvalue"), names(top))
      ft2 <- flextable(top[, cols, drop = FALSE])
      ft2 <- autofit(ft2)
      ft2 <- colformat_double(ft2, j = "mz", digits = 4)
      ft2 <- colformat_double(ft2, j = "rt", digits = 1)
      doc <- body_add_flextable(doc, ft2)
    }
  }

  # Section 4: Methods
  doc <- body_add_par(doc, "4. Methods", style = "heading 2")
  doc <- body_add_par(doc, methods_text, style = "Normal")

  # Save
  output_file <- file.path(output_dir, "report.docx")
  print(doc, target = output_file)
  output_file
}

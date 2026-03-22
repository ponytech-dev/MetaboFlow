##############################################################################
##  report-worker/plumber.R
##  Plumber HTTP API — report-worker
##
##  Generates PDF (Quarto) and Word (officer) reports from MetaboData HDF5.
##  Port: 8009
##############################################################################

library(plumber)

## ========================= Shared helpers =========================

## Structured JSON response envelope
ok_response <- function(data, message = "success") {
  list(status = "success", data = data, message = message)
}

err_response <- function(message, data = NULL) {
  list(status = "error", data = data, message = as.character(message))
}

## Simple request logger
log_request <- function(method, path, body_keys = character()) {
  ts  <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  cat(sprintf("[%s] %s %s  params: [%s]\n",
              ts, method, path, paste(body_keys, collapse = ", ")))
}


## ========================= /health =========================

#* Return worker health status and R version
#* @get /health
function() {
  log_request("GET", "/health")
  ok_response(
    data = list(
      worker    = "report-worker",
      version   = "1.0.0",
      r_version = paste(R.version$major, R.version$minor, sep = ".")
    ),
    message = "ok"
  )
}


## ========================= /generate =========================

#* Generate PDF and/or Word report from a MetaboData HDF5 file
#* @param metabodata_path  Full path to MetaboData .h5 file
#* @param chart_dir        Directory containing chart PNGs from chart-r-worker
#* @param output_dir       Directory to write report output files
#* @param format           "pdf", "word", or "both" (default: "both")
#* @param selected_charts  Optional JSON array of chart base names (without .png)
#* @post /generate
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  metabodata_path  <- body$metabodata_path
  chart_dir        <- body$chart_dir
  output_dir       <- body$output_dir
  format           <- if (!is.null(body$format)) body$format else "both"
  selected_charts  <- body$selected_charts  # NULL or character vector

  log_request("POST", "/generate", names(body))

  # Input validation
  if (is.null(metabodata_path) || nchar(metabodata_path) == 0)
    return(err_response("metabodata_path is required"))
  if (is.null(chart_dir) || nchar(chart_dir) == 0)
    return(err_response("chart_dir is required"))
  if (is.null(output_dir) || nchar(output_dir) == 0)
    return(err_response("output_dir is required"))
  if (!format %in% c("pdf", "word", "both"))
    return(err_response("format must be 'pdf', 'word', or 'both'"))

  if (!file.exists(metabodata_path))
    return(err_response(paste("metabodata_path not found:", metabodata_path)))
  if (!dir.exists(chart_dir))
    return(err_response(paste("chart_dir not found:", chart_dir)))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  result <- tryCatch({
    outputs <- list()

    if (format %in% c("word", "both")) {
      cat("=== Generating Word report ===\n")
      docx_path <- render_word_report(
        metabodata_path = metabodata_path,
        chart_dir       = chart_dir,
        output_dir      = output_dir,
        selected_charts = selected_charts
      )
      outputs$word <- docx_path
      cat("  Word report saved:", docx_path, "\n")
    }

    if (format %in% c("pdf", "both")) {
      cat("=== Generating PDF report ===\n")
      pdf_path <- render_pdf_report(
        metabodata_path = metabodata_path,
        chart_dir       = chart_dir,
        output_dir      = output_dir,
        selected_charts = selected_charts
      )
      outputs$pdf <- pdf_path
      cat("  PDF report saved:", pdf_path, "\n")
    }

    ok_response(
      data    = outputs,
      message = sprintf("Report generation complete (%s)", format)
    )
  }, error = function(e) {
    cat("[ERROR] /generate:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}

##############################################################################
##  chart-r-worker/plumber.R
##  Plumber HTTP API — chart-r-worker
##
##  Renders publication-grade charts from MetaboData HDF5 files.
##  Port: 8008
##
##  Endpoints:
##    POST /render                              — render a template
##    GET  /templates                           — list available templates
##    GET  /templates/{name}/interpretation/{lang} — get interpretation markdown
##    GET  /health                              — health check
##############################################################################

library(plumber)
library(jsonlite)

## ========================= Shared helpers =========================

## Structured JSON response envelope (mirrors xcms-worker pattern)
ok_response <- function(data, message = "success") {
  list(status = "success", data = data, message = message)
}

err_response <- function(message, data = NULL) {
  list(status = "error", data = data, message = as.character(message))
}

## Simple request logger
log_request <- function(method, path, body_keys = character()) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  cat(sprintf("[%s] %s %s  params: [%s]\n",
              ts, method, path, paste(body_keys, collapse = ", ")))
}

## Load registry once at startup
.registry <- tryCatch(
  jsonlite::fromJSON("/app/registry.json", simplifyVector = FALSE),
  error = function(e) list(version = "unknown", templates = list())
)


## ========================= /health =========================

#* Return worker health status and R version
#* @get /health
function() {
  log_request("GET", "/health")
  ok_response(
    data = list(
      worker    = "chart-r-worker",
      version   = "1.0.0",
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      templates = length(.registry$templates)
    ),
    message = "ok"
  )
}


## ========================= /templates =========================

#* Return all registered chart templates
#* @get /templates
#* @serializer json
function() {
  log_request("GET", "/templates")
  ok_response(
    data    = .registry,
    message = paste(length(.registry$templates), "templates registered")
  )
}


## ========================= /templates/{name}/interpretation/{lang} =========================

#* Return interpretation markdown for a template and language
#* @param name Template ID (e.g. "volcano_plot")
#* @param lang Language code: "zh" or "en"
#* @get /templates/<name>/interpretation/<lang>
#* @serializer json
function(name, lang) {
  log_request("GET", paste0("/templates/", name, "/interpretation/", lang))

  if (!lang %in% c("zh", "en")) {
    return(err_response(paste("Unsupported language:", lang, "— use 'zh' or 'en'")))
  }

  md_path <- file.path("/app/interpretations", lang, paste0(name, ".md"))
  if (!file.exists(md_path)) {
    return(err_response(paste("Interpretation not found:", name, "/", lang)))
  }

  content <- paste(readLines(md_path, warn = FALSE), collapse = "\n")
  ok_response(
    data = list(
      template = name,
      lang     = lang,
      content  = content
    )
  )
}


## ========================= /render =========================

#* Render a chart template from MetaboData HDF5 and return file paths
#* @param template      Template ID (e.g. "volcano_plot")
#* @param metabodata_path  Full path to .metabodata or .h5 file
#* @param output_dir    Directory to write SVG/PDF/PNG outputs
#* @param mzml_dir      Optional: directory containing raw mzML files
#* @param params        Optional: JSON object of template-specific parameters
#* @post /render
#* @serializer json
function(req) {
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
    error = function(e) list()
  )

  template         <- body$template
  metabodata_path  <- body$metabodata_path
  output_dir       <- body$output_dir
  mzml_dir         <- body$mzml_dir   # may be NULL
  params           <- if (!is.null(body$params)) body$params else list()

  log_request("POST", "/render", names(body))

  # Validate required fields
  if (is.null(template) || nchar(template) == 0)
    return(err_response("template is required"))
  if (is.null(metabodata_path) || nchar(metabodata_path) == 0)
    return(err_response("metabodata_path is required"))
  if (!file.exists(metabodata_path))
    return(err_response(paste("metabodata_path not found:", metabodata_path)))
  if (is.null(output_dir) || nchar(output_dir) == 0)
    return(err_response("output_dir is required"))

  result <- tryCatch({
    source("/app/R/render_template.R")

    paths <- render_template(
      template_name   = template,
      metabodata_path = metabodata_path,
      output_dir      = output_dir,
      mzml_dir        = mzml_dir,
      params          = params
    )

    ok_response(
      data = list(
        template = template,
        svg      = paths$svg,
        pdf      = paths$pdf,
        png      = paths$png
      ),
      message = paste("Rendered:", template)
    )
  }, error = function(e) {
    cat("[ERROR] /render:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}

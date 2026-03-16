##############################################################################
##  xcms-worker/plumber.R
##  Plumber HTTP API — xcms-worker
##
##  Exposes peak detection, preprocessing, and annotation as REST endpoints.
##  Python backend calls these via HTTP JSON.
##  Port: 8001
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
    data    = list(
      worker  = "xcms-worker",
      version = "1.0.0",
      r_version = paste(R.version$major, R.version$minor, sep = ".")
    ),
    message = "ok"
  )
}


## ========================= /params =========================

#* Return default parameters for all endpoints
#* @get /params
function() {
  log_request("GET", "/params")
  ok_response(
    data = list(
      peak_detection = list(
        polarity     = "positive",
        ppm          = 15,
        peakwidth    = c(5, 30),
        snthresh     = 5,
        noise        = 500,
        n_threads    = 4,
        min_fraction = 0.5
      ),
      preprocessing = list(
        intensity_floor = 1000,
        mv_method       = "knn",
        norm_method     = "median",
        polarity        = "positive"
      ),
      annotation = list(
        polarity = "positive",
        ms1_ppm  = 15,
        ms2_ppm  = 30
      )
    )
  )
}


## ========================= /peak_detection =========================

#* Run chromatographic peak detection via massprocesser
#* @param work_dir  Path to directory containing raw mzML/mzXML files
#* @param polarity  Ionization polarity: "positive" or "negative"
#* @param params    Optional parameter overrides (JSON object)
#* @post /peak_detection
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  work_dir <- body$work_dir
  polarity <- if (!is.null(body$polarity)) body$polarity else "positive"
  params   <- if (!is.null(body$params))   body$params   else list()

  log_request("POST", "/peak_detection", names(body))

  if (is.null(work_dir) || nchar(work_dir) == 0) {
    return(err_response("work_dir is required"))
  }

  result <- tryCatch({
    csv_path <- run_peak_detection(
      work_dir = work_dir,
      polarity = polarity,
      params   = params
    )
    ok_response(
      data    = list(result_csv = csv_path),
      message = paste("Peak detection complete:", csv_path)
    )
  }, error = function(e) {
    cat("[ERROR] /peak_detection:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}


## ========================= /preprocessing =========================

#* Build mass_dataset then run KNN imputation, intensity filter, and normalization
#* @param peak_table_path  Full path to peak_table_for_cleaning.csv
#* @param output_path      Full path to save the serialized mass_dataset (.rds)
#* @param sample_info      Optional sample info as a JSON array of objects
#* @param polarity         Ionization polarity
#* @param intensity_floor  Intensity floor for feature filtering (default 1000)
#* @param mv_method        Missing value imputation method (default "knn")
#* @param norm_method      Normalization method (default "median")
#* @post /preprocessing
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  peak_table_path <- body$peak_table_path
  output_path     <- body$output_path
  polarity        <- if (!is.null(body$polarity))        body$polarity        else "positive"
  intensity_floor <- if (!is.null(body$intensity_floor)) body$intensity_floor else 1000
  mv_method       <- if (!is.null(body$mv_method))       body$mv_method       else "knn"
  norm_method     <- if (!is.null(body$norm_method))     body$norm_method     else "median"

  ## Convert sample_info list-of-lists to data.frame if provided
  sample_info <- NULL
  if (!is.null(body$sample_info)) {
    sample_info <- tryCatch(
      as.data.frame(do.call(rbind, lapply(body$sample_info, as.data.frame)),
                    stringsAsFactors = FALSE),
      error = function(e) NULL
    )
  }

  log_request("POST", "/preprocessing", names(body))

  if (is.null(peak_table_path) || nchar(peak_table_path) == 0) {
    return(err_response("peak_table_path is required"))
  }
  if (is.null(output_path) || nchar(output_path) == 0) {
    return(err_response("output_path is required"))
  }

  result <- tryCatch({
    md <- build_mass_dataset(
      peak_table_path = peak_table_path,
      sample_info     = sample_info,
      polarity        = polarity
    )

    md_processed <- impute_filter_normalize(
      object          = md,
      intensity_floor = intensity_floor,
      mv_method       = mv_method,
      norm_method     = norm_method
    )

    ## Serialize the mass_dataset to disk for downstream steps
    saveRDS(md_processed, file = output_path)

    n_features <- nrow(md_processed@expression_data)
    n_samples  <- ncol(md_processed@expression_data)

    ok_response(
      data = list(
        output_rds  = output_path,
        n_features  = n_features,
        n_samples   = n_samples
      ),
      message = sprintf(
        "Preprocessing complete: %d features x %d samples -> %s",
        n_features, n_samples, output_path
      )
    )
  }, error = function(e) {
    cat("[ERROR] /preprocessing:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}


## ========================= /annotation =========================

#* Run multi-database metabolite annotation on a serialized mass_dataset
#* @param rds_path    Full path to preprocessed mass_dataset .rds file
#* @param output_path Full path to save the annotated mass_dataset (.rds)
#* @param db_dir      Directory containing all .rda / .database files
#* @param polarity    Ionization polarity
#* @param ms1_ppm     MS1 mass tolerance in ppm (default 15)
#* @param ms2_ppm     MS2 mass tolerance in ppm (default 30)
#* @post /annotation
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  rds_path    <- body$rds_path
  output_path <- body$output_path
  db_dir      <- body$db_dir
  polarity    <- if (!is.null(body$polarity))  body$polarity  else "positive"
  ms1_ppm     <- if (!is.null(body$ms1_ppm))   body$ms1_ppm   else 15
  ms2_ppm     <- if (!is.null(body$ms2_ppm))   body$ms2_ppm   else 30

  log_request("POST", "/annotation", names(body))

  if (is.null(rds_path) || nchar(rds_path) == 0) {
    return(err_response("rds_path is required"))
  }
  if (is.null(output_path) || nchar(output_path) == 0) {
    return(err_response("output_path is required"))
  }
  if (is.null(db_dir) || nchar(db_dir) == 0) {
    return(err_response("db_dir is required"))
  }

  result <- tryCatch({
    md <- readRDS(rds_path)

    md_annotated <- run_annotation(
      object  = md,
      db_dir  = db_dir,
      polarity = polarity,
      ms1_ppm  = ms1_ppm,
      ms2_ppm  = ms2_ppm
    )

    saveRDS(md_annotated, file = output_path)

    ok_response(
      data    = list(output_rds = output_path),
      message = paste("Annotation complete:", output_path)
    )
  }, error = function(e) {
    cat("[ERROR] /annotation:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}

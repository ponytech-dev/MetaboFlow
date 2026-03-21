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


## ========================= /run_pipeline =========================
## Unified pipeline: peak detection → deconvolution → preprocessing
## → outputs MetaboData HDF5 for cross-engine workflows.

#* Run full xcms pipeline, output MetaboData HDF5
#* @param mzml_dir    Directory containing mzML files
#* @param output_dir  Directory for outputs
#* @param polarity    "positive" or "negative" (default: "positive")
#* @param deconv_method  "camera", "cliquems", or "msflo" (default: "camera")
#* @post /run_pipeline
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  mzml_dir      <- body$mzml_dir
  output_dir    <- body$output_dir
  polarity      <- if (!is.null(body$polarity)) body$polarity else "positive"
  deconv_method <- if (!is.null(body$deconv_method)) body$deconv_method else "camera"

  log_request("POST", "/run_pipeline", names(body))

  if (is.null(mzml_dir) || nchar(mzml_dir) == 0)
    return(err_response("mzml_dir is required"))
  if (is.null(output_dir) || nchar(output_dir) == 0)
    return(err_response("output_dir is required"))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  pipeline_result <- tryCatch({
    suppressPackageStartupMessages({
      library(MSnbase)
      library(xcms)
    })
    source("/app/R/feature_deconvolution.R")
    source("/app/R/metabodata_bridge.R")

    ## --- Step 1: Peak Detection ---
    cat("=== Step 1: Peak Detection ===\n")
    mzml_files <- sort(list.files(mzml_dir, pattern = "\\.mzML$", full.names = TRUE))
    if (length(mzml_files) == 0) stop("No mzML files in ", mzml_dir)

    sample_names <- gsub("\\.mzML$", "", basename(mzml_files))
    sample_group <- ifelse(grepl("^SA|^WT|^CTL|^C", sample_names), "A", "B")

    raw_data <- readMSData(mzml_files, mode = "onDisk")
    raw_data <- filterMsLevel(raw_data, msLevel = 1L)
    cwp <- CentWaveParam(ppm = 5, peakwidth = c(5, 30), snthresh = 10,
                          noise = 1000, prefilter = c(3, 1000))
    xdata <- findChromPeaks(raw_data, param = cwp)
    pdp <- PeakDensityParam(sampleGroups = sample_group,
                             minFraction = 0.5, bw = 3, binSize = 0.025)
    xdata <- groupChromPeaks(xdata, param = pdp)
    if (length(mzml_files) >= 4) {
      pgp <- PeakGroupsParam(minFraction = 0.5)
      xdata <- adjustRtime(xdata, param = pgp)
      xdata <- groupChromPeaks(xdata, param = pdp)
    }
    xdata <- fillChromPeaks(xdata)
    feature_values <- featureValues(xdata, value = "into", method = "maxint")
    feature_defs   <- featureDefinitions(xdata)
    cat("  Features:", nrow(feature_values), "\n")

    ## --- Step 1b: Deconvolution ---
    cat("=== Step 1b: Deconvolution ===\n")
    deconv_result <- tryCatch(
      deconvolve_features(xdata, method = deconv_method, polarity = polarity),
      error = function(e) { cat("  Deconv skipped:", conditionMessage(e), "\n"); NULL }
    )

    ## --- Step 2: Preprocessing ---
    cat("=== Step 2: Preprocessing ===\n")
    int_matrix <- as.matrix(feature_values)
    keep <- rowMeans(is.na(int_matrix)) <= 0.5
    int_matrix <- int_matrix[keep, ]
    for (i in seq_len(nrow(int_matrix))) {
      na_idx <- is.na(int_matrix[i, ])
      if (any(na_idx)) int_matrix[i, na_idx] <- min(int_matrix[i, !na_idx], na.rm = TRUE) / 2
    }
    int_log <- log2(int_matrix + 1)
    col_med <- apply(int_log, 2, median)
    int_norm <- sweep(int_log, 2, median(col_med) - col_med, "+")
    cat("  Processed:", nrow(int_norm), "x", ncol(int_norm), "\n")

    ## --- Build MetaboData HDF5 ---
    cat("=== Building MetaboData ===\n")
    obs_df <- data.frame(sample_id = sample_names, group = sample_group,
                          batch = "1", sample_type = "sample",
                          row.names = sample_names, stringsAsFactors = FALSE)
    feat_ids <- rownames(int_norm)
    var_df <- data.frame(feature_id = feat_ids,
                          mz = feature_defs[feat_ids, "mzmed"],
                          rt = feature_defs[feat_ids, "rtmed"],
                          row.names = feat_ids, stringsAsFactors = FALSE)
    if (!is.null(deconv_result)) {
      m <- match(feat_ids, deconv_result$feature_id)
      var_df$adduct_group   <- deconv_result$adduct_group[m]
      var_df$adduct_type    <- deconv_result$adduct_type[m]
      var_df$representative <- deconv_result$representative[m]
    }

    md_path <- file.path(output_dir, "metabodata.h5")
    write_metabodata(
      X = t(int_norm), obs = obs_df, var = var_df,
      layers = list(raw = t(as.matrix(feature_values[feat_ids, ])), normalized = t(int_norm)),
      uns = list(engine = "xcms", engine_version = as.character(packageVersion("xcms")),
                  polarity = polarity, deconv_method = deconv_method,
                  n_features_raw = nrow(feature_values),
                  n_features_processed = nrow(int_norm),
                  timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
      path = md_path
    )
    write.csv(data.frame(feature_id = feat_ids, mz = var_df$mz, rt = var_df$rt,
                          int_norm, check.names = FALSE),
              file.path(output_dir, "peak_table.csv"), row.names = FALSE)
    cat("  Saved:", md_path, "\n")

    ok_response(
      data = list(metabodata_path = md_path,
                   peak_table_csv = file.path(output_dir, "peak_table.csv"),
                   n_samples = length(sample_names),
                   n_features = nrow(int_norm)),
      message = sprintf("Pipeline complete: %d features", nrow(int_norm))
    )
  }, error = function(e) {
    cat("[ERROR] /run_pipeline:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  pipeline_result
}

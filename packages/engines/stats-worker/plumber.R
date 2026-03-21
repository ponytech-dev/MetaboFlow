##############################################################################
##  stats-worker/plumber.R
##  Plumber HTTP API — stats-worker
##
##  Exposes differential analysis, pathway enrichment, and visualization
##  as REST endpoints.  Python backend calls these via HTTP JSON.
##  Port: 8002
##############################################################################

library(plumber)
library(limma)

## ========================= Shared helpers =========================

ok_response <- function(data, message = "success") {
  list(status = "success", data = data, message = message)
}

err_response <- function(message, data = NULL) {
  list(status = "error", data = data, message = as.character(message))
}

log_request <- function(method, path, body_keys = character()) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  cat(sprintf("[%s] %s %s  params: [%s]\n",
              ts, method, path, paste(body_keys, collapse = ", ")))
}

## Rebuild a default enrichment params list with config.R constants as fallback
.default_enrichment_params <- function(overrides = list()) {
  defaults <- list(
    alpha                   = 0.05,
    fc_cut                  = 0.176,
    organism                = "hsa",
    top_n_pathways          = TOP_N_PATHWAYS,
    filter_nonspecific      = TRUE,
    pathway_fig_w           = PATHWAY_FIG_W,
    pathway_fig_h           = PATHWAY_FIG_H,
    subfig_mode             = SUBFIG_MODE,
    nonspecific_keywords    = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient        = pathway_gradient,
    nature_colors           = nature_colors,
    volcano_colors          = volcano_colors,
    heatmap_colors          = heatmap_colors
  )
  ## Apply caller overrides
  for (k in names(overrides)) defaults[[k]] <- overrides[[k]]
  defaults
}


## ========================= /health =========================

#* Return worker health status and R version
#* @get /health
function() {
  log_request("GET", "/health")
  ok_response(
    data = list(
      worker    = "stats-worker",
      version   = "1.0.0",
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
      differential = list(
        alpha  = 0.05,
        fc_cut = 0.176
      ),
      enrichment = list(
        workflow                = "all",
        organism                = "hsa",
        alpha                   = 0.05,
        top_n_pathways          = TOP_N_PATHWAYS,
        filter_nonspecific      = TRUE,
        pathway_fig_w           = PATHWAY_FIG_W,
        pathway_fig_h           = PATHWAY_FIG_H,
        subfig_mode             = SUBFIG_MODE,
        nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF
      ),
      visualization = list(
        alpha       = 0.05,
        fc_cut      = 0.176,
        subfig_mode = SUBFIG_MODE
      )
    )
  )
}


## ========================= /differential =========================

#* Run limma differential analysis between two groups
#* @param ctl_rds    Path to control group expression matrix .rds (matrix: features × samples)
#* @param treat_rds  Path to treatment group expression matrix .rds
#* @param feature_names  JSON array of feature name strings (optional, uses rownames if omitted)
#* @param output_dir Directory where result xlsx files will be written
#* @param prefix     Filename prefix for result files
#* @param alpha      FDR significance threshold (default 0.05)
#* @param fc_cut     log10 FC cutoff (default 0.176)
#* @post /differential
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  ctl_rds    <- body$ctl_rds
  treat_rds  <- body$treat_rds
  output_dir <- body$output_dir
  prefix     <- if (!is.null(body$prefix))  body$prefix  else "diff"
  alpha      <- if (!is.null(body$alpha))   as.numeric(body$alpha)   else 0.05
  fc_cut     <- if (!is.null(body$fc_cut))  as.numeric(body$fc_cut)  else 0.176

  log_request("POST", "/differential", names(body))

  ## Validation
  for (field in c("ctl_rds", "treat_rds", "output_dir")) {
    if (is.null(body[[field]]) || nchar(body[[field]]) == 0) {
      return(err_response(paste(field, "is required")))
    }
  }

  result <- tryCatch({
    data_ctl   <- readRDS(ctl_rds)
    data_treat <- readRDS(treat_rds)

    feature_names <- if (!is.null(body$feature_names)) {
      unlist(body$feature_names)
    } else {
      rownames(data_ctl)
    }

    if (is.null(feature_names)) {
      stop("feature_names must be provided or present as rownames in ctl_rds")
    }

    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

    limma_res <- run_limma(
      data_ctl      = data_ctl,
      data_treat    = data_treat,
      feature_names = feature_names,
      alpha         = alpha,
      fc_cut        = fc_cut
    )

    ## Write full results table
    results_path <- file.path(output_dir, paste0(prefix, "_limma_results.csv"))
    write.csv(limma_res$results, results_path)

    sig_path <- file.path(output_dir, paste0(prefix, "_significant.csv"))
    write.csv(limma_res$significant, sig_path)

    ok_response(
      data = list(
        results_csv    = results_path,
        significant_csv = sig_path,
        n_total        = nrow(limma_res$results),
        n_significant  = nrow(limma_res$significant),
        used_raw_pval  = limma_res$used_raw_pval
      ),
      message = sprintf(
        "limma complete: %d total, %d significant (used_raw_pval=%s)",
        nrow(limma_res$results),
        nrow(limma_res$significant),
        limma_res$used_raw_pval
      )
    )
  }, error = function(e) {
    cat("[ERROR] /differential:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}


## ========================= /enrichment =========================

#* Run pathway enrichment — WF1 (SMPDB/tidymass), WF2 (MSEA), WF3 (KEGG), WF4 (QEA)
#* @param workflow      Which workflow(s) to run: "wf1", "wf2", "wf3", "wf4", or "all"
#* @param merged_rds    Path to merged data.frame .rds (annotation + differential columns)
#* @param output_dir    Directory for output files
#* @param prefix        Filename prefix
#* @param sample_cols   JSON array of expression column names present in merged_data
#* @param control_group Name of control group (for heatmap annotation)
#* @param model_group   Name of treatment group
#* @param params        JSON object of parameter overrides (optional)
#* @post /enrichment
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  workflow    <- if (!is.null(body$workflow))    tolower(body$workflow)   else "all"
  merged_rds  <- body$merged_rds
  output_dir  <- body$output_dir
  prefix      <- if (!is.null(body$prefix))      body$prefix              else "enrichment"
  sample_cols <- if (!is.null(body$sample_cols)) unlist(body$sample_cols) else character()
  ctrl_grp    <- if (!is.null(body$control_group)) body$control_group else "CTL"
  model_grp   <- if (!is.null(body$model_group))   body$model_group   else "TREAT"

  log_request("POST", "/enrichment", names(body))

  for (field in c("merged_rds", "output_dir")) {
    if (is.null(body[[field]]) || nchar(body[[field]]) == 0) {
      return(err_response(paste(field, "is required")))
    }
  }

  result <- tryCatch({
    merged_data <- readRDS(merged_rds)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

    ## Build params, injecting group labels and sample cols
    param_overrides        <- if (!is.null(body$params)) body$params else list()
    param_overrides$sample_cols    <- sample_cols
    param_overrides$control_group  <- ctrl_grp
    param_overrides$model_group    <- model_grp
    params <- .default_enrichment_params(param_overrides)

    ## Extract IDs for individual workflow dispatch
    hmdb_ids <- normalize_hmdb(merged_data$HMDB.ID)
    kegg_ids <- unique(merged_data$KEGG.ID[!is.na(merged_data$KEGG.ID) &
                                            merged_data$KEGG.ID != ""])

    wf_results <- list()

    if (workflow %in% c("wf1", "all")) {
      wf_results$wf1 <- run_wf1_smpdb(hmdb_ids, prefix, output_dir, params)
    }
    if (workflow %in% c("wf2", "all")) {
      wf_results$wf2 <- run_wf2_msea(hmdb_ids, prefix, output_dir, params)
    }
    if (workflow %in% c("wf3", "all")) {
      wf_results$wf3 <- run_wf3_kegg(kegg_ids, prefix, output_dir, params)
    }
    if (workflow %in% c("wf4", "all")) {
      ## Prepare QEA matrix
      qea_sub <- merged_data[!is.na(merged_data$Compound.name) &
                               merged_data$Compound.name != "", ]
      qea_sub <- unique(qea_sub[, c("Compound.name", sample_cols,
                                    setdiff(colnames(qea_sub),
                                            c("Compound.name", sample_cols)))])
      if (nrow(qea_sub) >= 5 && length(sample_cols) > 0) {
        qea_mat           <- as.matrix(qea_sub[, sample_cols])
        rownames(qea_mat) <- qea_sub$Compound.name
        group_labels      <- factor(gsub("[0-9]", "", colnames(qea_mat)))
        hmdb_to_name      <- stats::setNames(qea_sub$Compound.name,
                                             normalize_hmdb(qea_sub$HMDB.ID))
        params$hmdb_to_name <- hmdb_to_name
        wf_results$wf4    <- run_wf4_qea(qea_mat, group_labels, hmdb_ids,
                                         prefix, output_dir, params)
      } else {
        cat("  WF4: skipped (fewer than 5 metabolites or no sample_cols)\n")
      }
    }

    ran_wfs <- names(wf_results)
    ok_response(
      data    = list(output_dir = output_dir, workflows_run = ran_wfs),
      message = paste("Enrichment complete, ran:", paste(ran_wfs, collapse = ", "))
    )
  }, error = function(e) {
    cat("[ERROR] /enrichment:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}


## ========================= /visualization =========================

#* Generate volcano plot from limma results
#* @param results_rds  Path to limma results data.frame .rds (topTable output)
#* @param output_prefix Full path prefix for output files (no extension)
#* @param alpha         Significance threshold (default 0.05)
#* @param fc_cut        log10 FC cutoff (default 0.176)
#* @param p_col         Column name for p-values: "adj.P.Val" or "P.Value"
#* @param subfig_mode   Small sub-figure font mode (default FALSE)
#* @post /visualization
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  results_rds   <- body$results_rds
  output_prefix <- body$output_prefix
  alpha         <- if (!is.null(body$alpha))      as.numeric(body$alpha)      else 0.05
  fc_cut        <- if (!is.null(body$fc_cut))     as.numeric(body$fc_cut)     else 0.176
  p_col         <- if (!is.null(body$p_col))      body$p_col                  else "adj.P.Val"
  subfig_mode   <- if (!is.null(body$subfig_mode)) isTRUE(body$subfig_mode)   else FALSE

  log_request("POST", "/visualization", names(body))

  for (field in c("results_rds", "output_prefix")) {
    if (is.null(body[[field]]) || nchar(body[[field]]) == 0) {
      return(err_response(paste(field, "is required")))
    }
  }

  result <- tryCatch({
    res <- readRDS(results_rds)

    dir.create(dirname(output_prefix), recursive = TRUE, showWarnings = FALSE)

    plot_volcano_nature(
      res         = res,
      prefix      = output_prefix,
      alpha       = alpha,
      fc_cut      = fc_cut,
      colors      = volcano_colors,
      p_col       = p_col,
      subfig_mode = subfig_mode
    )

    pdf_path  <- paste0(output_prefix, ".pdf")
    tiff_path <- paste0(output_prefix, ".tiff")

    ok_response(
      data = list(
        pdf  = pdf_path,
        tiff = tiff_path
      ),
      message = paste("Volcano plot saved:", pdf_path)
    )
  }, error = function(e) {
    cat("[ERROR] /visualization:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  result
}


## ========================= /run_stats =========================
## Accepts MetaboData HDF5 from xcms-worker, runs differential analysis
## + pathway enrichment, outputs updated MetaboData HDF5.

#* Run differential analysis + pathway enrichment on MetaboData HDF5
#* @param metabodata_path  Path to MetaboData HDF5 file from xcms-worker
#* @param output_dir       Directory for outputs
#* @param alpha            Significance threshold (default: 0.05)
#* @param fc_cut           Log2 fold change cutoff (default: 1.0)
#* @post /run_stats
#* @serializer json
function(req) {
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
                   error = function(e) list())

  md_path    <- body$metabodata_path
  output_dir <- body$output_dir
  alpha      <- if (!is.null(body$alpha))  as.numeric(body$alpha)  else 0.05
  fc_cut     <- if (!is.null(body$fc_cut)) as.numeric(body$fc_cut) else 1.0

  log_request("POST", "/run_stats", names(body))

  if (is.null(md_path) || nchar(md_path) == 0)
    return(err_response("metabodata_path is required"))
  if (is.null(output_dir) || nchar(output_dir) == 0)
    return(err_response("output_dir is required"))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  stats_result <- tryCatch({
    source("/app/R/metabodata_bridge.R")
    source("/app/R/differential.R")

    ## Read MetaboData HDF5
    cat("=== Reading MetaboData ===\n")
    md <- read_metabodata(md_path)
    X   <- md$X            # samples x features
    obs <- md$obs
    var <- md$var

    groups <- obs$group
    cat("  Samples:", nrow(X), " Features:", ncol(X), "\n")
    cat("  Groups:", paste(unique(groups), collapse = "/"), "\n")

    ## Differential analysis (limma)
    cat("=== Differential Analysis (limma) ===\n")
    group_levels <- unique(groups)
    if (length(group_levels) != 2)
      stop("Exactly 2 groups required, found: ", paste(group_levels, collapse = ", "))

    ctl_idx   <- which(groups == group_levels[1])
    treat_idx <- which(groups == group_levels[2])

    limma_result <- run_limma(
      data_ctl      = t(X[ctl_idx, , drop = FALSE]),
      data_treat    = t(X[treat_idx, , drop = FALSE]),
      feature_names = var$feature_id,
      alpha         = alpha,
      fc_cut        = fc_cut
    )

    cat("  Significant:", nrow(limma_result$significant), "\n")

    ## Save results
    write.csv(limma_result$results, file.path(output_dir, "limma_all.csv"))
    write.csv(limma_result$significant, file.path(output_dir, "limma_significant.csv"))

    ## Update MetaboData: add stats results to uns
    md$uns$differential <- list(
      method     = "limma",
      alpha      = alpha,
      fc_cut     = fc_cut,
      n_significant = nrow(limma_result$significant),
      n_up       = sum(limma_result$results$logFC > fc_cut & limma_result$results[[if (limma_result$used_raw_pval) "P.Value" else "adj.P.Val"]] < alpha),
      n_down     = sum(limma_result$results$logFC < -fc_cut & limma_result$results[[if (limma_result$used_raw_pval) "P.Value" else "adj.P.Val"]] < alpha)
    )

    ## Add significance info to var
    var$logFC  <- limma_result$results[var$feature_id, "logFC"]
    var$pvalue <- limma_result$results[var$feature_id, if (limma_result$used_raw_pval) "P.Value" else "adj.P.Val"]
    var$significant <- var$feature_id %in% rownames(limma_result$significant)

    ## Write updated MetaboData
    md_out_path <- file.path(output_dir, "metabodata_stats.h5")
    write_metabodata(
      X = md$X, obs = md$obs, var = var,
      layers = md$layers, obsm = md$obsm, varm = md$varm,
      uns = md$uns, path = md_out_path
    )
    cat("  Updated MetaboData:", md_out_path, "\n")

    ok_response(
      data = list(
        metabodata_path = md_out_path,
        limma_all_csv   = file.path(output_dir, "limma_all.csv"),
        limma_sig_csv   = file.path(output_dir, "limma_significant.csv"),
        n_significant   = nrow(limma_result$significant)
      ),
      message = sprintf("Stats complete: %d significant features", nrow(limma_result$significant))
    )
  }, error = function(e) {
    cat("[ERROR] /run_stats:", conditionMessage(e), "\n")
    err_response(conditionMessage(e))
  })

  stats_result
}

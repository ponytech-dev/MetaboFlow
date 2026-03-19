##############################################################################
##  annotation_ms1.R
##  MS1-level metabolite annotation (Level 3) for xcms-based pipelines
##
##  Loads a pre-built compound database CSV (exact_mass + formula + IDs),
##  calculates theoretical m/z for common adducts, and matches detected
##  features within ppm tolerance.
##  No dependency on tidymass, massdataset, or spectral library parsing.
##############################################################################

## Common ESI adducts: name -> mass shift (added to neutral monoisotopic mass)
ESI_POS_ADDUCTS <- data.frame(
  adduct = c("[M+H]+", "[M+Na]+", "[M+K]+", "[M+NH4]+"),
  delta  = c(1.007276, 22.989218, 38.963158, 18.034164),
  stringsAsFactors = FALSE
)

ESI_NEG_ADDUCTS <- data.frame(
  adduct = c("[M-H]-", "[M+FA-H]-", "[M+Cl]-"),
  delta  = c(-1.007276, 44.998201, 34.969402),
  stringsAsFactors = FALSE
)

## Load Level 3 compound database from CSV
## Expected columns: name, formula, exact_mass, kegg_id, hmdb_id, chebi_id, lipidmaps_id, source
load_compound_db <- function(csv_path) {
  if (!file.exists(csv_path)) {
    stop("Compound database not found: ", csv_path)
  }
  cat("  Loading compound database:", basename(csv_path), "...")
  db <- read.csv(csv_path, stringsAsFactors = FALSE)
  db$exact_mass <- as.numeric(db$exact_mass)
  db <- db[!is.na(db$exact_mass) & db$exact_mass > 0, ]
  cat(" loaded", nrow(db), "compounds\n")
  db
}

## Pre-compute theoretical m/z for all compounds x adducts
## Returns a data.frame with: compound_idx, adduct, theoretical_mz
compute_theoretical_mz <- function(compound_db, polarity = "positive") {
  adducts <- if (polarity == "positive") ESI_POS_ADDUCTS else ESI_NEG_ADDUCTS
  masses <- compound_db$exact_mass

  rows <- list()
  n <- 0L
  for (a in seq_len(nrow(adducts))) {
    theo_mz <- masses + adducts$delta[a]
    valid <- theo_mz > 50  # skip unreasonable values
    idx <- which(valid)
    if (length(idx) > 0) {
      n <- n + 1L
      rows[[n]] <- data.frame(
        compound_idx   = idx,
        adduct         = adducts$adduct[a],
        theoretical_mz = theo_mz[idx],
        stringsAsFactors = FALSE
      )
    }
  }

  theo_df <- do.call(rbind, rows)
  # Sort by theoretical m/z for fast binary search
  theo_df <- theo_df[order(theo_df$theoretical_mz), ]
  cat("  Pre-computed", nrow(theo_df), "theoretical m/z values (",
      nrow(adducts), "adducts x", nrow(compound_db), "compounds)\n")
  theo_df
}

## MS1-level annotation using pre-computed theoretical m/z
##
## @param feature_mz   numeric vector of feature m/z values
## @param feature_ids  character vector of feature IDs
## @param feature_rt   numeric vector of feature RT in seconds (optional)
## @param compound_db  data.frame from load_compound_db()
## @param theo_mz_df   data.frame from compute_theoretical_mz()
## @param ppm_tol      matching tolerance in ppm (default 5)
## @param max_matches  maximum matches per feature (default 3)
##
## @return data.frame with annotation results
annotate_ms1 <- function(feature_mz,
                          feature_ids,
                          feature_rt = NULL,
                          compound_db,
                          theo_mz_df,
                          ppm_tol = 5,
                          max_matches = 3) {
  cat("  MS1 annotation:", length(feature_mz), "features x",
      nrow(theo_mz_df), "theoretical m/z (ppm=", ppm_tol, ")...\n")

  theo_mz_vec <- theo_mz_df$theoretical_mz
  results <- list()
  n_matched <- 0L

  for (i in seq_along(feature_mz)) {
    obs_mz <- feature_mz[i]
    fid <- feature_ids[i]
    frt <- if (!is.null(feature_rt)) feature_rt[i] else NA

    # Binary search for m/z window
    mz_tol <- obs_mz * ppm_tol / 1e6
    lo <- obs_mz - mz_tol
    hi <- obs_mz + mz_tol

    idx_lo <- findInterval(lo, theo_mz_vec) + 1L
    idx_hi <- findInterval(hi, theo_mz_vec)

    if (idx_lo > idx_hi || idx_lo > length(theo_mz_vec)) next

    candidates <- theo_mz_df[idx_lo:idx_hi, ]
    ppm_err <- abs(candidates$theoretical_mz - obs_mz) / obs_mz * 1e6
    candidates$ppm_error <- ppm_err

    # Sort by ppm error and take top matches
    candidates <- candidates[order(candidates$ppm_error), ]
    if (nrow(candidates) > max_matches) {
      candidates <- candidates[1:max_matches, ]
    }

    for (j in seq_len(nrow(candidates))) {
      cidx <- candidates$compound_idx[j]
      cpd <- compound_db[cidx, ]
      n_matched <- n_matched + 1L
      results[[n_matched]] <- data.frame(
        feature_id   = fid,
        mz           = obs_mz,
        rt           = frt,
        matched_name = cpd$name,
        formula      = cpd$formula,
        adduct       = candidates$adduct[j],
        ppm_error    = round(candidates$ppm_error[j], 2),
        kegg_id      = cpd$kegg_id,
        hmdb_id      = cpd$hmdb_id,
        chebi_id     = cpd$chebi_id,
        lipidmaps_id = cpd$lipidmaps_id,
        source       = cpd$source,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0) {
    cat("  No matches found\n")
    return(data.frame(
      feature_id = character(), mz = numeric(), rt = numeric(),
      matched_name = character(), formula = character(),
      adduct = character(), ppm_error = numeric(),
      kegg_id = character(), hmdb_id = character(),
      chebi_id = character(), lipidmaps_id = character(),
      source = character(), stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, results)
  n_features_matched <- length(unique(out$feature_id))
  cat("  Matched:", n_features_matched, "features ->", nrow(out), "annotations\n")
  out
}

## Summarize annotation results
summarize_annotations <- function(ann_df) {
  if (nrow(ann_df) == 0) return(list(n_matched = 0, n_unique_compounds = 0))

  best <- ann_df[order(ann_df$ppm_error), ]
  best <- best[!duplicated(best$feature_id), ]

  list(
    n_matched           = length(unique(ann_df$feature_id)),
    n_total_annotations = nrow(ann_df),
    n_unique_compounds  = length(unique(best$matched_name)),
    n_with_kegg         = sum(best$kegg_id != "", na.rm = TRUE),
    n_with_hmdb         = sum(best$hmdb_id != "", na.rm = TRUE),
    adduct_distribution = table(ann_df$adduct),
    source_distribution = table(ann_df$source)
  )
}

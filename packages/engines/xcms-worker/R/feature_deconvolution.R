##############################################################################
##  feature_deconvolution.R
##  Feature deconvolution: adduct grouping, isotope annotation,
##  in-source fragment detection
##
##  Three engines available (user selects one or more):
##    1. CAMERA   — classic, widely cited, Bioconductor
##    2. CliqueMS — graph-based, newer algorithm
##    3. MS-FLO   — post-processing deduplication
##
##  Input:  xcms XCMSnExp object (after peak detection + grouping)
##  Output: annotated feature table with:
##          - adduct_group: which features belong to the same compound
##          - adduct_type:  [M+H]+, [M+Na]+, [M+K]+, etc.
##          - isotope:      [M]+, [M+1]+, [M+2]+, etc.
##          - is_fragment:  TRUE if likely in-source fragment
##          - representative: TRUE if this is the primary ion for the group
##############################################################################

## ========================= CAMERA =========================

run_camera <- function(xdata, polarity = "positive", sigma = 6, perfwhm = 0.6) {
  if (!requireNamespace("CAMERA", quietly = TRUE)) {
    cat("  CAMERA not installed, skipping\n")
    return(NULL)
  }
  library(CAMERA)
  cat("  Running CAMERA adduct/isotope annotation...\n")

  # Convert XCMSnExp to xcmsSet (CAMERA still uses old API)
  xs <- as(xdata, "xcmsSet")

  # Step 1: Group correlated features by RT and correlation
  an <- xsAnnotate(xs)
  an <- groupFWHM(an, perfwhm = perfwhm, sigma = sigma)

  # Step 2: Find isotope patterns
  an <- findIsotopes(an, mzabs = 0.01, ppm = 10)

  # Step 3: Annotate adducts
  if (polarity == "positive") {
    an <- findAdducts(an, polarity = "positive",
                      rules = NULL,  # use default positive rules
                      ppm = 10)
  } else {
    an <- findAdducts(an, polarity = "negative",
                      rules = NULL,
                      ppm = 10)
  }

  # Extract annotation results
  peak_list <- getPeaklist(an)
  cat("  CAMERA: ", nrow(peak_list), " features annotated\n")
  cat("  Isotope groups: ", length(unique(peak_list$isotopes[peak_list$isotopes != ""])), "\n")
  cat("  Adduct annotations: ", sum(peak_list$adduct != ""), "\n")
  cat("  PC groups (compound groups): ", max(peak_list$pcgroup, na.rm = TRUE), "\n")

  # Build deconvolution result
  result <- data.frame(
    feature_id     = rownames(peak_list),
    mz             = peak_list$mz,
    rt             = peak_list$rt,
    adduct_group   = peak_list$pcgroup,
    adduct_type    = peak_list$adduct,
    isotope        = peak_list$isotopes,
    is_fragment    = grepl("\\[M\\]", peak_list$isotopes) == FALSE &
                     peak_list$adduct == "" &
                     peak_list$isotopes == "",
    method         = "CAMERA",
    stringsAsFactors = FALSE
  )

  # Mark representative ion per group (highest intensity)
  if ("into" %in% colnames(peak_list)) {
    int_cols <- grep("^X\\d|^SA|^SB|^S\\d", colnames(peak_list))
    if (length(int_cols) > 0) {
      result$mean_intensity <- rowMeans(peak_list[, int_cols, drop = FALSE], na.rm = TRUE)
    } else {
      result$mean_intensity <- 0
    }
  } else {
    result$mean_intensity <- 0
  }

  # Representative = highest intensity in each group
  result$representative <- FALSE
  for (grp in unique(result$adduct_group)) {
    idx <- which(result$adduct_group == grp)
    best <- idx[which.max(result$mean_intensity[idx])]
    result$representative[best] <- TRUE
  }

  result
}


## ========================= CliqueMS =========================

run_cliquems <- function(xdata, polarity = "positive") {
  if (!requireNamespace("cliqueMS", quietly = TRUE)) {
    cat("  CliqueMS not installed, skipping\n")
    return(NULL)
  }
  library(cliqueMS)
  cat("  Running CliqueMS graph-based annotation...\n")

  # CliqueMS works with xcmsSet
  xs <- as(xdata, "xcmsSet")

  # Step 1: Compute cliques (groups of co-eluting features)
  cliques <- getCliques(xs, filter = TRUE)

  # Step 2: Annotate adducts within cliques
  if (polarity == "positive") {
    ann <- getAnnotation(cliques, polarity = "positive", ppm = 10)
  } else {
    ann <- getAnnotation(cliques, polarity = "negative", ppm = 10)
  }

  # Extract results
  ann_df <- as.data.frame(ann)
  cat("  CliqueMS: ", nrow(ann_df), " features in ", length(unique(ann_df$cliqueGroup)),
      " clique groups\n")

  # Build standardized result
  result <- data.frame(
    feature_id     = ann_df$feature,
    mz             = ann_df$mz,
    rt             = ann_df$rt,
    adduct_group   = ann_df$cliqueGroup,
    adduct_type    = ifelse(!is.na(ann_df$an1), ann_df$an1, ""),
    isotope        = ifelse(!is.na(ann_df$isoGroup), paste0("iso_", ann_df$isoGroup), ""),
    is_fragment    = FALSE,  # CliqueMS doesn't explicitly detect fragments
    method         = "CliqueMS",
    stringsAsFactors = FALSE
  )

  result
}


## ========================= MS-FLO (post-processing) =========================

run_msflo <- function(peak_table, rt_tol = 10, mz_adduct_tol_ppm = 10) {
  cat("  Running MS-FLO-style deduplication...\n")

  # MS-FLO logic: for each pair of features within RT tolerance,
  # check if their m/z difference matches a known adduct mass difference
  adduct_diffs <- data.frame(
    name = c("[M+Na]+-[M+H]+", "[M+K]+-[M+H]+", "[M+NH4]+-[M+H]+",
             "[2M+H]+-[M+H]+", "[M+2H]2+-[M+H]+"),
    diff = c(21.98194, 37.95588, 17.02655, 0, 0),  # 0 = special handling
    stringsAsFactors = FALSE
  )

  n <- nrow(peak_table)
  groups <- rep(NA, n)
  group_id <- 0
  adduct_labels <- rep("", n)

  for (i in 1:n) {
    if (!is.na(groups[i])) next
    group_id <- group_id + 1
    groups[i] <- group_id
    adduct_labels[i] <- "[M+H]+"  # assume primary

    for (j in (i+1):min(n, i+500)) {
      if (j > n) break
      if (!is.na(groups[j])) next

      rt_diff <- abs(peak_table$rt[i] - peak_table$rt[j])
      if (rt_diff > rt_tol) next

      mz_diff <- peak_table$mz[j] - peak_table$mz[i]

      # Check against known adduct differences
      for (k in 1:nrow(adduct_diffs)) {
        expected <- adduct_diffs$diff[k]
        if (expected == 0) next
        tol <- peak_table$mz[i] * mz_adduct_tol_ppm / 1e6
        if (abs(mz_diff - expected) < tol) {
          groups[j] <- group_id
          adduct_labels[j] <- gsub("-\\[M\\+H\\]\\+", "", adduct_diffs$name[k])
          break
        }
      }
    }
  }

  result <- data.frame(
    feature_id     = peak_table$feature_id,
    mz             = peak_table$mz,
    rt             = peak_table$rt,
    adduct_group   = groups,
    adduct_type    = adduct_labels,
    isotope        = "",
    is_fragment    = FALSE,
    method         = "MS-FLO",
    stringsAsFactors = FALSE
  )

  # Mark representative (first in each group = highest m/z typically [M+H]+)
  result$representative <- !duplicated(result$adduct_group)

  n_groups <- length(unique(groups))
  n_redundant <- n - n_groups
  cat("  MS-FLO: ", n, " features -> ", n_groups, " compound groups (",
      n_redundant, " redundant)\n")

  result
}


## ========================= Unified interface =========================

deconvolve_features <- function(xdata,
                                 peak_table = NULL,
                                 method = "camera",
                                 polarity = "positive") {
  method <- tolower(method)
  cat("===== Feature Deconvolution (method:", method, ") =====\n")

  result <- switch(method,
    "camera"   = run_camera(xdata, polarity),
    "cliquems" = run_cliquems(xdata, polarity),
    "msflo"    = {
      if (is.null(peak_table)) stop("MS-FLO requires peak_table input")
      run_msflo(peak_table)
    },
    stop("Unknown method: ", method, ". Use 'camera', 'cliquems', or 'msflo'")
  )

  if (!is.null(result)) {
    n_total <- nrow(result)
    n_groups <- length(unique(result$adduct_group))
    n_repr <- sum(result$representative, na.rm = TRUE)
    cat("  Summary: ", n_total, " features -> ", n_groups, " compound groups\n")
    cat("  Representative ions: ", n_repr, "\n")
    cat("  Redundant features: ", n_total - n_repr, "\n")
  }

  result
}

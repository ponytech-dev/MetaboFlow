##############################################################################
##  metabodata_bridge.R
##  R ↔ Python MetaboData HDF5 bridge
##
##  Reads/writes MetaboData .metabodata (HDF5) files from R,
##  compatible with Python metabodata.io.save_metabodata/load_metabodata.
##
##  This enables cross-engine data flow:
##    xcms-worker (R) → MetaboData HDF5 → stats-worker (R) or annot-worker (Python)
##
##  Dependencies: rhdf5 (Bioconductor), jsonlite
##############################################################################

## Write MetaboData to HDF5 file
##
## @param X          numeric matrix (n_samples x n_features)
## @param obs        data.frame with sample metadata (rownames = sample_id)
## @param var        data.frame with feature metadata (rownames = feature_id)
## @param layers     named list of matrices (e.g., list(raw=..., normalized=...))
## @param obsm       named list of matrices (e.g., list(pca=...))
## @param varm       named list of matrices (e.g., list(pca_loadings=...))
## @param uns        named list (unstructured metadata, will be JSON-encoded)
## @param path       output file path (.metabodata or .h5)
write_metabodata <- function(X, obs, var, path,
                              layers = list(), obsm = list(),
                              varm = list(), uns = list()) {
  if (!requireNamespace("rhdf5", quietly = TRUE)) {
    stop("rhdf5 is required. Install via BiocManager::install('rhdf5')")
  }
  library(rhdf5)

  # Create file
  rhdf5::h5createFile(path)

  # Write X matrix
  rhdf5::h5write(as.matrix(X), path, "X")

  # Write obs (sample metadata)
  rhdf5::h5createGroup(path, "obs")
  .write_dataframe_hdf5(obs, path, "obs")

  # Write var (feature metadata)
  rhdf5::h5createGroup(path, "var")
  .write_dataframe_hdf5(var, path, "var")

  # Write layers
  if (length(layers) > 0) {
    rhdf5::h5createGroup(path, "layers")
    for (nm in names(layers)) {
      rhdf5::h5write(as.matrix(layers[[nm]]), path, paste0("layers/", nm))
    }
  }

  # Write obsm
  if (length(obsm) > 0) {
    rhdf5::h5createGroup(path, "obsm")
    for (nm in names(obsm)) {
      rhdf5::h5write(as.matrix(obsm[[nm]]), path, paste0("obsm/", nm))
    }
  }

  # Write varm
  if (length(varm) > 0) {
    rhdf5::h5createGroup(path, "varm")
    for (nm in names(varm)) {
      rhdf5::h5write(as.matrix(varm[[nm]]), path, paste0("varm/", nm))
    }
  }

  # Write uns as JSON string
  uns_json <- jsonlite::toJSON(uns, auto_unbox = TRUE, pretty = FALSE)
  rhdf5::h5write(as.character(uns_json), path, "uns")

  rhdf5::H5close()
  invisible(path)
}


## Read MetaboData from HDF5 file
##
## @param path  input file path (.metabodata or .h5)
## @return named list with X, obs, var, layers, obsm, varm, uns
read_metabodata <- function(path) {
  if (!requireNamespace("rhdf5", quietly = TRUE)) {
    stop("rhdf5 is required. Install via BiocManager::install('rhdf5')")
  }
  library(rhdf5)

  result <- list()

  # Read X matrix
  result$X <- rhdf5::h5read(path, "X")

  # Read obs
  result$obs <- .read_dataframe_hdf5(path, "obs")

  # Read var
  result$var <- .read_dataframe_hdf5(path, "var")

  # Read layers
  result$layers <- list()
  contents <- rhdf5::h5ls(path, recursive = FALSE)
  if ("layers" %in% contents$name) {
    layer_contents <- rhdf5::h5ls(path, recursive = TRUE)
    layer_names <- layer_contents$name[layer_contents$group == "/layers"]
    for (nm in layer_names) {
      result$layers[[nm]] <- rhdf5::h5read(path, paste0("layers/", nm))
    }
  }

  # Read obsm
  result$obsm <- list()
  if ("obsm" %in% contents$name) {
    obsm_contents <- rhdf5::h5ls(path, recursive = TRUE)
    obsm_names <- obsm_contents$name[obsm_contents$group == "/obsm"]
    for (nm in obsm_names) {
      result$obsm[[nm]] <- rhdf5::h5read(path, paste0("obsm/", nm))
    }
  }

  # Read varm
  result$varm <- list()
  if ("varm" %in% contents$name) {
    varm_contents <- rhdf5::h5ls(path, recursive = TRUE)
    varm_names <- varm_contents$name[varm_contents$group == "/varm"]
    for (nm in varm_names) {
      result$varm[[nm]] <- rhdf5::h5read(path, paste0("varm/", nm))
    }
  }

  # Read uns
  if ("uns" %in% contents$name) {
    uns_raw <- rhdf5::h5read(path, "uns")
    result$uns <- jsonlite::fromJSON(uns_raw)
  } else {
    result$uns <- list()
  }

  rhdf5::H5close()
  result
}


## Internal: Write data.frame to HDF5 group
.write_dataframe_hdf5 <- function(df, path, group_name) {
  # Write index
  idx <- rownames(df)
  if (is.null(idx)) idx <- as.character(seq_len(nrow(df)))
  rhdf5::h5write(idx, path, paste0(group_name, "/_index"))

  # Write column names as attribute
  col_names <- jsonlite::toJSON(colnames(df), auto_unbox = FALSE)
  fid <- rhdf5::H5Fopen(path)
  gid <- rhdf5::H5Gopen(fid, group_name)
  rhdf5::h5writeAttribute(as.character(col_names), gid, "column_names")
  rhdf5::H5Gclose(gid)
  rhdf5::H5Fclose(fid)

  # Write each column
  for (col in colnames(df)) {
    vals <- df[[col]]
    if (is.numeric(vals)) {
      rhdf5::h5write(as.double(vals), path, paste0(group_name, "/", col))
    } else {
      rhdf5::h5write(as.character(vals), path, paste0(group_name, "/", col))
    }
  }
}


## Internal: Read data.frame from HDF5 group
.read_dataframe_hdf5 <- function(path, group_name) {
  # Read index
  idx <- rhdf5::h5read(path, paste0(group_name, "/_index"))

  # Read column names — try attribute first, fallback to listing datasets
  col_names <- tryCatch({
    fid <- rhdf5::H5Fopen(path)
    gid <- rhdf5::H5Gopen(fid, group_name)
    col_names_json <- rhdf5::h5readAttributes(gid, "column_names")
    rhdf5::H5Gclose(gid)
    rhdf5::H5Fclose(fid)
    jsonlite::fromJSON(col_names_json)
  }, error = function(e) {
    # Fallback: infer column names from datasets in group (exclude _index)
    contents <- rhdf5::h5ls(path)
    grp_contents <- contents[contents$group == paste0("/", group_name), ]
    setdiff(grp_contents$name, "_index")
  })

  # Read columns
  data <- list()
  for (col in col_names) {
    data[[col]] <- rhdf5::h5read(path, paste0(group_name, "/", col))
  }

  df <- as.data.frame(data, stringsAsFactors = FALSE)
  rownames(df) <- idx
  df
}

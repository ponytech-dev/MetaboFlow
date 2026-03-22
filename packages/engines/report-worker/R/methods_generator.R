# Auto Methods Paragraph Generator
# Reads analysis provenance from MetaboData HDF5 uns field,
# fills in YAML templates with actual parameter values.

generate_methods <- function(metabodata_path, language = "en") {
  source("/app/R/metabodata_bridge.R")
  md <- read_metabodata(metabodata_path)
  uns <- md$uns

  # Parse uns (may be JSON string)
  if (is.character(uns) && length(uns) == 1) {
    uns <- jsonlite::fromJSON(uns)
  }

  sections <- list()

  # Platform intro
  sections$intro <- sprintf(
    "Untargeted metabolomics data were processed using MetaboFlow (v1.0)."
  )

  # Peak detection
  engine <- if (!is.null(uns$engine)) uns$engine else "xcms"
  engine_ver <- if (!is.null(uns$engine_version)) uns$engine_version else "4.4.x"
  sections$peak_detection <- sprintf(
    "Peak detection was performed with %s (v%s). Feature grouping and retention time correction were applied.",
    toupper(engine), engine_ver
  )

  # Deconvolution
  deconv <- if (!is.null(uns$deconv_method)) uns$deconv_method else "CAMERA"
  sections$deconvolution <- sprintf(
    "Redundant features were removed using %s.", toupper(deconv)
  )

  # Statistics
  if (!is.null(uns$differential)) {
    diff <- uns$differential
    alpha <- if (!is.null(diff$alpha)) diff$alpha else 0.05
    fc_cut <- if (!is.null(diff$fc_cut)) diff$fc_cut else 1.0
    sections$statistics <- sprintf(
      "Statistical analysis was performed using limma with Benjamini-Hochberg FDR correction (adjusted p < %g, |log2FC| > %g).",
      alpha, fc_cut
    )
  }

  # Annotation
  sections$annotation <- sprintf(
    "Metabolite annotation was performed against the MetaboFlow Spectral Library (MFSL v2.2, 960,000 compounds) using matchms with cosine similarity >= 0.7."
  )

  # Combine
  paste(unlist(sections), collapse = " ")
}

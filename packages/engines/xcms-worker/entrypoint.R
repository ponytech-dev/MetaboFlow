##############################################################################
##  xcms-worker/entrypoint.R
##  Sources all R modules then starts the Plumber API on port 8001.
##############################################################################

## Resolve the script's own directory so source() works from any working dir
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) getwd()
)

cat("=== xcms-worker starting ===\n")
cat("Script dir:", script_dir, "\n")

## Source all R modules in dependency order
for (f in c("utils.R", "peak_detection.R", "preprocessing.R", "annotation.R")) {
  path <- file.path(script_dir, "R", f)
  cat("Loading:", path, "\n")
  source(path)
}

cat("All modules loaded. Starting Plumber on port 8001...\n")

library(plumber)

pr <- plumb(file.path(script_dir, "plumber.R"))

pr$run(
  host = "0.0.0.0",
  port = 8001,
  swagger = FALSE
)

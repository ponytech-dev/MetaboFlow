##############################################################################
##  stats-worker/entrypoint.R
##  Sources all R modules then starts the Plumber API on port 8002.
##############################################################################

## Resolve the script's own directory so source() works from any working dir
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) getwd()
)

cat("=== stats-worker starting ===\n")
cat("Script dir:", script_dir, "\n")

## Source in dependency order: config first, then visualization, then enrichment/differential
for (f in c("config.R", "visualization.R", "differential.R", "enrichment.R")) {
  path <- file.path(script_dir, "R", f)
  cat("Loading:", path, "\n")
  source(path)
}

cat("All modules loaded. Starting Plumber on port 8002...\n")

library(plumber)

pr <- plumb(file.path(script_dir, "plumber.R"))

pr$run(
  host   = "0.0.0.0",
  port   = 8002,
  swagger = FALSE
)

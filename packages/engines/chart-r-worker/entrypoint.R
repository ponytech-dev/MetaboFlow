##############################################################################
##  chart-r-worker/entrypoint.R
##  Container entrypoint — loads core modules then starts Plumber on port 8008
##############################################################################

cat("=== chart-r-worker starting ===\n")
script_dir <- Sys.getenv("SCRIPT_DIR", "/app")
cat("Script dir:", script_dir, "\n")

# Load core modules
for (f in c("metabodata_bridge.R", "metaboflow_theme.R",
            "color_palettes.R", "render_template.R")) {
  fpath <- file.path(script_dir, "R", f)
  cat("Loading:", fpath, "\n")
  source(fpath)
}

cat("All modules loaded. Starting Plumber on port 8008...\n")

pr <- plumber::plumb(file.path(script_dir, "plumber.R"))
pr$run(host = "0.0.0.0", port = 8008L)

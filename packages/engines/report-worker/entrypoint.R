cat("=== report-worker starting ===\n")
script_dir <- Sys.getenv("SCRIPT_DIR", "/app")
for (f in c("metabodata_bridge.R", "methods_generator.R", "render_pdf.R", "render_word.R")) {
  fpath <- file.path(script_dir, "R", f)
  cat("Loading:", fpath, "\n")
  source(fpath)
}
cat("All modules loaded. Starting Plumber on port 8009...\n")
pr <- plumber::plumb(file.path(script_dir, "plumber.R"))
pr$run(host = "0.0.0.0", port = 8009L)

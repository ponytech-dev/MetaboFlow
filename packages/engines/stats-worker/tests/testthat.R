## Test runner for stats-worker
library(testthat)

## Source all R files
r_dir <- file.path(dirname(dirname(getwd())), "R")
if (dir.exists(r_dir)) {
  r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
  invisible(lapply(r_files, function(f) {
    tryCatch(source(f), error = function(e) {
      message("Could not source ", f, ": ", conditionMessage(e))
    })
  }))
}

test_dir("testthat")

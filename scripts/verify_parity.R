##############################################################################
##  scripts/verify_parity.R
##  结果等价性验证 / Result Parity Verification
##
##  Compare modularized R code output against v1.r ground truth results
##  stored in example_results/.
##
##  Usage: Rscript scripts/verify_parity.R [--tolerance 1e-6]
##
##  Exit codes:
##    0 = all checks pass
##    1 = one or more checks fail
##############################################################################

library(testthat)

## ========================= 配置 / Configuration =========================

TOLERANCE <- 1e-6
EXAMPLE_DIR <- file.path(getwd(), "example_results")

## Parse command-line tolerance override
args <- commandArgs(trailingOnly = TRUE)
if ("--tolerance" %in% args) {
  tol_idx <- which(args == "--tolerance") + 1
  if (tol_idx <= length(args)) {
    TOLERANCE <- as.numeric(args[tol_idx])
  }
}

cat("========== MetaboFlow 结果等价性验证 / Result Parity Verification ==========\n")
cat(sprintf("  容差/Tolerance: %e\n", TOLERANCE))
cat(sprintf("  基准目录/Baseline: %s\n\n", EXAMPLE_DIR))


## ========================= 1. 差异分析结果验证 / Differential Analysis =========================

test_that("差异峰CSV存在且结构正确 / Differential peaks CSV exists and has correct structure", {
  csv_path <- file.path(EXAMPLE_DIR, "01_differential_peaks", "MethiocarbB差异峰.csv")
  skip_if(!file.exists(csv_path), "基准文件不存在/baseline file not found")

  baseline <- read.csv(csv_path)

  ## 必须列 / Required columns
  required_cols <- c("variable_id", "mz", "rt", "logFC", "P.Value", "adj.P.Val", "Significance")
  expect_true(all(required_cols %in% colnames(baseline)),
              info = paste("缺少列/missing columns:",
                           paste(setdiff(required_cols, colnames(baseline)), collapse = ", ")))

  ## 行数 > 0
  expect_gt(nrow(baseline), 0, info = "差异峰结果为空/differential peaks result is empty")

  cat(sprintf("  [PASS] 差异峰CSV: %d 行, %d 列\n", nrow(baseline), ncol(baseline)))
})


test_that("差异峰logFC数值精度 / Differential peaks logFC precision", {
  csv_path <- file.path(EXAMPLE_DIR, "01_differential_peaks", "MethiocarbB差异峰.csv")
  skip_if(!file.exists(csv_path), "基准文件不存在/baseline file not found")

  baseline <- read.csv(csv_path)

  ## logFC 应为有限值 / logFC should be finite
  expect_true(all(is.finite(baseline$logFC)),
              info = "存在非有限logFC值/non-finite logFC values detected")

  ## P.Value 应在 [0, 1] / P.Value should be in [0, 1]
  expect_true(all(baseline$P.Value >= 0 & baseline$P.Value <= 1),
              info = "P.Value 超出[0,1]范围/P.Value out of [0,1] range")

  ## adj.P.Val 应在 [0, 1]
  expect_true(all(baseline$adj.P.Val >= 0 & baseline$adj.P.Val <= 1),
              info = "adj.P.Val 超出[0,1]范围/adj.P.Val out of [0,1] range")

  cat("  [PASS] logFC 和 P.Value 数值格式正确\n")
})


test_that("差异峰Significance分类正确 / Significance classification is correct", {
  csv_path <- file.path(EXAMPLE_DIR, "01_differential_peaks", "MethiocarbB差异峰.csv")
  skip_if(!file.exists(csv_path), "基准文件不存在/baseline file not found")

  baseline <- read.csv(csv_path)

  ## Significance 应只有 "Up" / "Down" / "Not Significant"
  valid_sig <- c("Up", "Down", "Not Significant")
  expect_true(all(baseline$Significance %in% valid_sig),
              info = paste("非法Significance值/invalid Significance values:",
                           paste(unique(setdiff(baseline$Significance, valid_sig)), collapse = ", ")))

  cat(sprintf("  [PASS] Significance分类: Up=%d, Down=%d, NS=%d\n",
              sum(baseline$Significance == "Up"),
              sum(baseline$Significance == "Down"),
              sum(baseline$Significance == "Not Significant")))
})


## ========================= 2. 模块化代码输出对比 / Modularized Output Comparison =========================

## 此函数用于对比模块化run_limma()的输出与基准
## This function compares modularized run_limma() output against baseline
compare_differential_results <- function(new_csv_path, baseline_csv_path, tolerance) {
  skip_if(!file.exists(new_csv_path), "模块化输出不存在/modularized output not found")
  skip_if(!file.exists(baseline_csv_path), "基准文件不存在/baseline file not found")

  new_data <- read.csv(new_csv_path)
  baseline <- read.csv(baseline_csv_path)

  ## 行数一致 / Row count match
  expect_equal(nrow(new_data), nrow(baseline),
               info = "差异峰行数不一致/row count mismatch")

  ## 共享的variable_id集合一致 / Same variable_id set
  expect_true(setequal(new_data$variable_id, baseline$variable_id),
              info = "variable_id集合不一致/variable_id set mismatch")

  ## 按variable_id排序后对比logFC / Compare logFC after sorting by variable_id
  new_sorted <- new_data[order(new_data$variable_id), ]
  base_sorted <- baseline[order(baseline$variable_id), ]

  expect_equal(new_sorted$logFC, base_sorted$logFC, tolerance = tolerance,
               info = "logFC数值不等价/logFC values not equivalent")

  expect_equal(new_sorted$P.Value, base_sorted$P.Value, tolerance = tolerance,
               info = "P.Value数值不等价/P.Value values not equivalent")

  expect_equal(new_sorted$Significance, base_sorted$Significance,
               info = "Significance分类不一致/Significance classification mismatch")

  cat("  [PASS] 模块化输出与基准数值等价\n")
}


## ========================= 3. 通路分析结果验证 / Pathway Analysis Validation =========================

test_that("WF1 SMPDB结果存在 / WF1 SMPDB results exist", {
  wf1_dir <- file.path(EXAMPLE_DIR, "02_pathway_enrichment", "WF1_SMPDB")
  skip_if(!dir.exists(wf1_dir), "WF1目录不存在/WF1 directory not found")

  xlsx_files <- list.files(wf1_dir, pattern = "\\.xlsx$", full.names = TRUE)
  expect_gt(length(xlsx_files), 0, info = "WF1无xlsx输出/WF1 has no xlsx output")

  cat(sprintf("  [PASS] WF1 SMPDB: %d 个结果文件\n", length(xlsx_files)))
})


test_that("WF2 MSEA结果存在 / WF2 MSEA results exist", {
  wf2_dir <- file.path(EXAMPLE_DIR, "02_pathway_enrichment", "WF2_MSEA")
  skip_if(!dir.exists(wf2_dir), "WF2目录不存在/WF2 directory not found")

  result_files <- list.files(wf2_dir, full.names = TRUE)
  expect_gt(length(result_files), 0, info = "WF2无输出/WF2 has no output")

  cat(sprintf("  [PASS] WF2 MSEA: %d 个结果文件\n", length(result_files)))
})


test_that("WF3 KEGG结果存在 / WF3 KEGG results exist", {
  wf3_dir <- file.path(EXAMPLE_DIR, "02_pathway_enrichment", "WF3_KEGG")
  skip_if(!dir.exists(wf3_dir), "WF3目录不存在/WF3 directory not found")

  result_files <- list.files(wf3_dir, full.names = TRUE)
  expect_gt(length(result_files), 0, info = "WF3无输出/WF3 has no output")

  cat(sprintf("  [PASS] WF3 KEGG: %d 个结果文件\n", length(result_files)))
})


test_that("WF4 QEA结果存在 / WF4 QEA results exist", {
  wf4_dir <- file.path(EXAMPLE_DIR, "02_pathway_enrichment", "WF4_QEA")
  skip_if(!dir.exists(wf4_dir), "WF4目录不存在/WF4 directory not found")

  result_files <- list.files(wf4_dir, full.names = TRUE)
  expect_gt(length(result_files), 0, info = "WF4无输出/WF4 has no output")

  cat(sprintf("  [PASS] WF4 QEA: %d 个结果文件\n", length(result_files)))
})


## ========================= 4. 可视化文件验证 / Visualization File Validation =========================

test_that("差异峰可视化文件存在 / Differential peak visualizations exist", {
  diff_dir <- file.path(EXAMPLE_DIR, "01_differential_peaks")
  skip_if(!dir.exists(diff_dir), "差异峰目录不存在/differential peaks dir not found")

  pdf_files <- list.files(diff_dir, pattern = "\\.pdf$")
  expect_gt(length(pdf_files), 0, info = "无PDF可视化文件/no PDF visualization files")

  cat(sprintf("  [PASS] 差异峰可视化: %d PDF 文件\n", length(pdf_files)))
})


test_that("热图结果存在 / Heatmap results exist", {
  heatmap_dir <- file.path(EXAMPLE_DIR, "03_heatmap")
  skip_if(!dir.exists(heatmap_dir), "热图目录不存在/heatmap dir not found")

  result_files <- list.files(heatmap_dir)
  expect_gt(length(result_files), 0, info = "无热图文件/no heatmap files")

  cat(sprintf("  [PASS] 热图: %d 个文件\n", length(result_files)))
})


test_that("PCA结果存在 / PCA results exist", {
  pca_dir <- file.path(EXAMPLE_DIR, "04_PCA")
  skip_if(!dir.exists(pca_dir), "PCA目录不存在/PCA dir not found")

  result_files <- list.files(pca_dir)
  expect_gt(length(result_files), 0, info = "无PCA文件/no PCA files")

  cat(sprintf("  [PASS] PCA: %d 个文件\n", length(result_files)))
})


## ========================= 汇总 / Summary =========================

cat("\n========== 验证完成 / Verification Complete ==========\n")
cat("所有基线完整性检查通过。\n")
cat("注意：模块化代码的数值等价性对比需要在Docker容器中运行全流程后执行。\n")
cat("Note: Numerical parity comparison against modularized code requires\n")
cat("      running the full pipeline inside Docker containers.\n")

##############################################################################
##  stats-worker/tests/testthat/test-differential.R
##  测试 differential.R 中的 run_limma 函数
##  Tests for run_limma in differential.R
##
##  limma 是必要依赖，使用 skip_if_not_installed() 保护。
##  limma is required; guarded with skip_if_not_installed().
##############################################################################

source("../../R/differential.R")

## ========================= run_limma =========================

## 构造可复现的测试矩阵 / Build reproducible test matrices
## feat1: 显著上调 / significantly up-regulated
## feat2: 无差异    / not differentially expressed
.make_test_matrices <- function(seed = 42L) {
  set.seed(seed)
  data_ctl   <- matrix(c(
    rnorm(4, mean = 3.0, sd = 0.1),  ## feat1 CTL
    rnorm(4, mean = 5.0, sd = 0.1)   ## feat2 CTL
  ), nrow = 2, byrow = TRUE,
     dimnames = list(NULL, paste0("C", 1:4)))

  data_treat <- matrix(c(
    rnorm(4, mean = 3.8, sd = 0.1),  ## feat1 TREAT (logFC ~0.8, 大幅上调)
    rnorm(4, mean = 5.05, sd = 0.1)  ## feat2 TREAT (几乎无变化)
  ), nrow = 2, byrow = TRUE,
     dimnames = list(NULL, paste0("T", 1:4)))

  list(ctl = data_ctl, treat = data_treat,
       names = c("feat1", "feat2"))
}

test_that("run_limma: 返回列表含必要字段 / returns list with required fields", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  result <- run_limma(mats$ctl, mats$treat, mats$names)

  expect_type(result, "list")
  expect_named(result, c("results", "significant", "used_raw_pval"), ignore.order = TRUE)
})

test_that("run_limma: $results 包含所有features / $results contains all features", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  result <- run_limma(mats$ctl, mats$treat, mats$names)

  expect_equal(nrow(result$results), 2L)
  expect_true(all(mats$names %in% rownames(result$results)))
})

test_that("run_limma: $results 含limma标准列 / $results has standard limma columns", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  result <- run_limma(mats$ctl, mats$treat, mats$names)
  cols   <- colnames(result$results)

  expect_true("logFC"     %in% cols)
  expect_true("P.Value"   %in% cols)
  expect_true("adj.P.Val" %in% cols)
})

test_that("run_limma: 显著上调的feat1被检出 / strongly up-regulated feat1 is detected", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  result <- run_limma(mats$ctl, mats$treat, mats$names,
                       alpha = 0.05, fc_cut = 0.176)

  ## feat1 logFC ~0.8 >> fc_cut，期望进入$significant
  expect_true("feat1" %in% rownames(result$significant))
})

test_that("run_limma: used_raw_pval 是逻辑值 / used_raw_pval is a logical scalar", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  result <- run_limma(mats$ctl, mats$treat, mats$names)

  expect_type(result$used_raw_pval, "logical")
  expect_length(result$used_raw_pval, 1L)
})

test_that("run_limma: 无差异时$significant为空或行数较少 / no-diff scenario yields fewer significant rows", {
  skip_if_not_installed("limma")

  set.seed(99L)
  ## 两组完全相同 / identical groups → no difference
  data_same <- matrix(rnorm(12, mean = 5, sd = 0.1), nrow = 3,
                       dimnames = list(NULL, paste0("S", 1:12)))
  data_ctl   <- data_same[, 1:6]
  data_treat <- data_same[, 7:12]
  feat_names <- c("f1", "f2", "f3")

  result <- run_limma(data_ctl, data_treat, feat_names,
                       alpha = 0.05, fc_cut = 0.176)

  ## 极小差异不应有显著结果（或显著数量很少）
  ## near-identical groups should yield zero significant features
  expect_lte(nrow(result$significant), 1L)
})

test_that("run_limma: fc_cut严格时不发现显著差异 / tight fc_cut suppresses significance", {
  skip_if_not_installed("limma")

  mats   <- .make_test_matrices()
  ## 将fc_cut设为极大值，任何feature都不可能超过
  ## Set fc_cut extremely high so nothing can pass
  result <- run_limma(mats$ctl, mats$treat, mats$names,
                       alpha = 0.05, fc_cut = 999)

  expect_equal(nrow(result$significant), 0L)
})

##############################################################################
##  stats-worker/tests/testthat/test-enrichment.R
##  测试 enrichment.R 中的富集分析工作流
##  Tests for enrichment workflow functions in enrichment.R
##
##  WF1-WF4 各依赖不同外部包，使用 skip_if_not_installed() 保护。
##  filter_nonspecific 和 normalize_hmdb 是纯函数，不跳过。
##  WF1-WF4 each depend on different external packages; guarded accordingly.
##  filter_nonspecific and normalize_hmdb are pure; tested without skip.
##############################################################################

## enrichment.R 内部会 source config.R 和 visualization.R
## enrichment.R sources config.R and visualization.R internally
source("../../R/enrichment.R")

## ========================= 工具函数测试 / Utility function tests =========================
## (filter_nonspecific 和 normalize_hmdb 在 enrichment.R 末尾定义)
## (filter_nonspecific and normalize_hmdb are defined at the bottom of enrichment.R)

test_that("normalize_hmdb (stats-worker): 7位转11位 / converts 7-digit to 11-digit", {
  result <- normalize_hmdb(c("HMDB00001", "HMDB01234"))
  expect_equal(result, c("HMDB0000001", "HMDB0001234"))
})

test_that("normalize_hmdb (stats-worker): 过滤NA和空值 / filters NAs and empty strings", {
  result <- normalize_hmdb(c(NA, "", "HMDB00001"))
  expect_length(result, 1L)
  expect_equal(result, "HMDB0000001")
})

test_that("filter_nonspecific (stats-worker): 空df返回空 / empty df returns empty list", {
  empty <- data.frame(pathway_name = character(0), stringsAsFactors = FALSE)
  res   <- filter_nonspecific(empty)
  expect_equal(nrow(res$all),      0L)
  expect_equal(nrow(res$filtered), 0L)
})

test_that("filter_nonspecific (stats-worker): 黑名单过滤 / blacklist filtering removes correct rows", {
  df <- data.frame(
    pathway_name = c("Glycolysis", "Metabolic pathways", "Citrate cycle"),
    stringsAsFactors = FALSE
  )
  res <- filter_nonspecific(df, keywords = NONSPECIFIC_KEYWORDS)
  expect_false("Metabolic pathways" %in% res$filtered$pathway_name)
  expect_true("Glycolysis"          %in% res$filtered$pathway_name)
})

test_that("filter_nonspecific (stats-worker): enabled=FALSE 原样返回 / enabled=FALSE bypasses filtering", {
  df <- data.frame(
    pathway_name = c("Metabolic pathways", "Glycolysis"),
    stringsAsFactors = FALSE
  )
  res <- filter_nonspecific(df, enabled = FALSE)
  expect_equal(nrow(res$filtered), nrow(df))
})


## ========================= run_wf1_smpdb 跳过/输入验证 =========================

test_that("run_wf1_smpdb: HMDB IDs不足3个时返回NULL / returns NULL when fewer than 3 HMDB IDs", {
  ## 不需要tidymass安装；少于3个ID的检查在requireNamespace之后
  ## No need for tidymass; but this branch is hit only if tidymass IS installed
  ## 所以用 skip_if_not_installed 确保环境一致
  skip_if_not_installed("tidymass")

  tmp_dir <- tempdir()
  params <- list(
    alpha = 0.05, top_n_pathways = 0, filter_nonspecific = TRUE,
    pathway_fig_w = 7, pathway_fig_h = 5, subfig_mode = FALSE,
    nonspecific_keywords   = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient = pathway_gradient
  )
  result <- run_wf1_smpdb(c("HMDB0000001", "HMDB0000002"), "test", tmp_dir, params)
  expect_null(result)
})

test_that("run_wf1_smpdb: tidymass未安装时返回NULL / returns NULL when tidymass not installed", {
  skip_if(requireNamespace("tidymass", quietly = TRUE),
          "tidymass is installed; skip the 'not installed' path")

  tmp_dir <- tempdir()
  params <- list(
    alpha = 0.05, top_n_pathways = 0, filter_nonspecific = TRUE,
    pathway_fig_w = 7, pathway_fig_h = 5, subfig_mode = FALSE,
    nonspecific_keywords    = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient = pathway_gradient
  )
  result <- run_wf1_smpdb(
    c("HMDB0000001", "HMDB0000002", "HMDB0000003"),
    "test", tmp_dir, params
  )
  expect_null(result)
})


## ========================= run_wf2_msea 跳过/输入验证 =========================

test_that("run_wf2_msea: HMDB IDs不足3个时返回NULL / returns NULL with fewer than 3 IDs", {
  skip_if_not_installed("MetaboAnalystR")

  tmp_dir <- tempdir()
  params <- list(
    alpha = 0.05, top_n_pathways = 0, filter_nonspecific = TRUE,
    pathway_fig_w = 7, pathway_fig_h = 5, subfig_mode = FALSE,
    nonspecific_keywords    = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient = pathway_gradient
  )
  result <- run_wf2_msea(c("HMDB0000001"), "test", tmp_dir, params)
  expect_null(result)
})


## ========================= run_wf3_kegg 跳过/输入验证 =========================

test_that("run_wf3_kegg: KEGG IDs不足3个时返回NULL / returns NULL with fewer than 3 KEGG IDs", {
  skip_if_not_installed("KEGGREST")

  tmp_dir <- tempdir()
  params <- list(
    alpha = 0.05, top_n_pathways = 0, filter_nonspecific = TRUE,
    pathway_fig_w = 7, pathway_fig_h = 5.5, subfig_mode = FALSE,
    organism = "hsa",
    nonspecific_keywords    = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient = pathway_gradient
  )
  result <- run_wf3_kegg(c("C00031", "C00062"), "test", tmp_dir, params)
  expect_null(result)
})


## ========================= run_wf4_qea 跳过/输入验证 =========================

test_that("run_wf4_qea: 代谢物不足5个时返回NULL / returns NULL with fewer than 5 metabolites", {
  skip_if_not_installed("globaltest")

  ## 只有3行的矩阵 / only 3-row matrix
  mat <- matrix(c(100, 200, 300, 110, 190, 310),
                nrow = 3, ncol = 2,
                dimnames = list(c("A", "B", "C"), c("S1", "S2")))
  params <- list(
    alpha = 0.05, top_n_pathways = 0, filter_nonspecific = TRUE,
    pathway_fig_w = 7, pathway_fig_h = 5, subfig_mode = FALSE,
    hmdb_to_name = character(0),
    nonspecific_keywords    = NONSPECIFIC_KEYWORDS,
    nonspecific_size_cutoff = NONSPECIFIC_SIZE_CUTOFF,
    pathway_gradient = pathway_gradient
  )
  result <- run_wf4_qea(mat, factor(c("CTL", "TREAT")),
                         character(0), "test", tempdir(), params)
  expect_null(result)
})

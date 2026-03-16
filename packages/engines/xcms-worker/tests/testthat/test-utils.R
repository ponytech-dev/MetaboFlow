##############################################################################
##  xcms-worker/tests/testthat/test-utils.R
##  测试 utils.R 中的纯工具函数
##  Tests for pure utility functions in utils.R
##
##  这些函数不依赖外部包，所有测试均不跳过。
##  These functions have no external package dependencies; no skips needed.
##############################################################################

source("../../R/utils.R")

## ========================= normalize_hmdb =========================

test_that("normalize_hmdb: 7位转11位 / converts 7-digit to 11-digit", {
  result <- normalize_hmdb(c("HMDB00001", "HMDB01234"))
  ## 7位格式 HMDB + 5位数字 → 补两个0后变11位
  ## 7-digit format HMDB + 5 digits → padded to 11 digits
  expect_equal(result, c("HMDB0000001", "HMDB0001234"))
})

test_that("normalize_hmdb: 已是11位的保持不变 / keeps already-valid 11-digit IDs unchanged", {
  ids <- c("HMDB0000001", "HMDB0123456")
  result <- normalize_hmdb(ids)
  expect_equal(result, ids)
})

test_that("normalize_hmdb: 去除NA和空字符串 / removes NAs and empty strings", {
  result <- normalize_hmdb(c("HMDB00001", NA, "", "HMDB00002"))
  expect_false(any(is.na(result)))
  expect_false("" %in% result)
  expect_length(result, 2L)
})

test_that("normalize_hmdb: 去重 / deduplicates identical IDs", {
  result <- normalize_hmdb(c("HMDB00001", "HMDB00001", "HMDB0000001"))
  ## 两个输入都归一化为同一个ID后去重
  ## Both inputs normalize to same ID, so deduplication leaves 1
  expect_length(result, 1L)
})

test_that("normalize_hmdb: 全为NA/空时返回长度0向量 / returns length-0 vector for all-NA/empty input", {
  result <- normalize_hmdb(c(NA, "", NA))
  expect_length(result, 0L)
  expect_is(result, "character")
})

test_that("normalize_hmdb: 非标准格式不变 / non-standard IDs pass through unchanged", {
  ## 不符合7位也不符合11位的ID原样保留
  ## IDs that match neither pattern are left as-is
  result <- normalize_hmdb(c("CHEBI:12345", "CID123"))
  expect_equal(result, c("CHEBI:12345", "CID123"))
})


## ========================= filter_nonspecific =========================

## 构造测试用data.frame / Build a minimal test data.frame
.make_pathway_df <- function() {
  data.frame(
    pathway_name = c(
      "Glycolysis",
      "Metabolic pathways",
      "Citrate cycle",
      "ABC transporters",
      "Big generic pathway"
    ),
    all_number = c(20L, 200L, 15L, 180L, 160L),
    stringsAsFactors = FALSE
  )
}

test_that("filter_nonspecific: 关键词黑名单过滤生效 / keyword blacklist removes matching rows", {
  df <- .make_pathway_df()
  result <- filter_nonspecific(df, size_col = "all_number")
  ## "Metabolic pathways" 和 "ABC transporters" 在默认黑名单中
  expect_false("Metabolic pathways" %in% result$filtered$pathway_name)
  expect_false("ABC transporters"   %in% result$filtered$pathway_name)
})

test_that("filter_nonspecific: $all 始终包含完整未过滤结果 / $all always holds the unfiltered input", {
  df <- .make_pathway_df()
  result <- filter_nonspecific(df)
  expect_equal(nrow(result$all), nrow(df))
})

test_that("filter_nonspecific: size_cutoff 过滤超大通路 / removes rows above size_cutoff", {
  df <- .make_pathway_df()
  ## "Big generic pathway" 大小160 > 150，但不在关键词黑名单中
  result <- filter_nonspecific(df, size_col = "all_number", size_cutoff = 150)
  expect_false("Big generic pathway" %in% result$filtered$pathway_name)
})

test_that("filter_nonspecific: enabled=FALSE 原样返回 / enabled=FALSE returns df unchanged in both slots", {
  df <- .make_pathway_df()
  result <- filter_nonspecific(df, enabled = FALSE)
  expect_equal(result$all,      df)
  expect_equal(result$filtered, df)
})

test_that("filter_nonspecific: 空data.frame直接返回 / empty data.frame returns list of two empty dfs", {
  empty_df <- data.frame(pathway_name = character(0), stringsAsFactors = FALSE)
  result   <- filter_nonspecific(empty_df)
  expect_equal(nrow(result$all),      0L)
  expect_equal(nrow(result$filtered), 0L)
})

test_that("filter_nonspecific: 无黑名单匹配时filtered等于all / no blacklist matches → filtered equals all", {
  df <- data.frame(
    pathway_name = c("Glycolysis", "Citrate cycle"),
    stringsAsFactors = FALSE
  )
  result <- filter_nonspecific(df)
  expect_equal(nrow(result$filtered), nrow(df))
})


## ========================= prep_pathway_plot =========================

test_that("prep_pathway_plot: top_n=0 保留全部行 / top_n=0 keeps all rows", {
  df     <- data.frame(x = 1:10)
  result <- prep_pathway_plot(df, top_n = 0)
  expect_equal(nrow(result), 10L)
})

test_that("prep_pathway_plot: top_n 截断至指定行数 / top_n truncates to n rows", {
  df     <- data.frame(x = 1:10)
  result <- prep_pathway_plot(df, top_n = 5)
  expect_equal(nrow(result), 5L)
})

test_that("prep_pathway_plot: top_n > nrow 时保留全部 / top_n larger than nrow keeps all rows", {
  df     <- data.frame(x = 1:3)
  result <- prep_pathway_plot(df, top_n = 100)
  expect_equal(nrow(result), 3L)
})

test_that("prep_pathway_plot: 空data.frame直接返回 / empty df returned unchanged", {
  df     <- data.frame(x = integer(0))
  result <- prep_pathway_plot(df, top_n = 5)
  expect_equal(nrow(result), 0L)
})

test_that("prep_pathway_plot: top_n=NULL 保留全部行 / top_n=NULL keeps all rows", {
  df     <- data.frame(x = 1:7)
  result <- prep_pathway_plot(df, top_n = NULL)
  expect_equal(nrow(result), 7L)
})

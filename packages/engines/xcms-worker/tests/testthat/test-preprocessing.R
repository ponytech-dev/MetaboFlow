##############################################################################
##  xcms-worker/tests/testthat/test-preprocessing.R
##  测试 preprocessing.R 中的预处理函数
##  Tests for preprocessing functions in preprocessing.R
##
##  build_mass_dataset 和 impute_filter_normalize 均依赖 massdataset，
##  使用 skip_if_not_installed() 保护。
##  Both functions depend on massdataset; guarded with skip_if_not_installed().
##############################################################################

source("../../R/preprocessing.R")

## ========================= build_mass_dataset =========================

test_that("build_mass_dataset: 文件不存在时报错 / errors when file does not exist", {
  ## 这是纯错误路径测试，不需要外部包
  ## This tests the error path before any package is loaded
  expect_error(
    build_mass_dataset("/nonexistent/path/peak_table.csv"),
    regexp = "不存在|does not exist"
  )
})

test_that("build_mass_dataset: 从CSV构建mass_dataset对象 / builds mass_dataset from CSV", {
  skip_if_not_installed("massdataset")

  ## 构造最小peak_table CSV / Build a minimal peak_table CSV
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)

  peak_df <- data.frame(
    mz  = c(100.01, 200.02, 300.03),
    rt  = c(10.0, 20.0, 30.0),
    S1  = c(5000, 6000, 7000),
    S2  = c(5100, 5900, 7200),
    row.names = c("feat1", "feat2", "feat3"),
    stringsAsFactors = FALSE
  )
  write.csv(peak_df, tmp_csv)

  obj <- build_mass_dataset(tmp_csv)

  ## 验证返回的是mass_dataset对象 / Verify returned object class
  expect_s4_class(obj, "mass_dataset")

  ## 验证variable_info行数正确 / Verify variable count
  expect_equal(nrow(massdataset::extract_variable_info(obj)), 3L)
})

test_that("build_mass_dataset: 自定义sample_info正确绑定 / custom sample_info is bound correctly", {
  skip_if_not_installed("massdataset")

  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)

  peak_df <- data.frame(
    mz  = c(100.01, 200.02),
    rt  = c(10.0, 20.0),
    S1  = c(5000, 6000),
    S2  = c(5100, 5900),
    row.names = c("feat1", "feat2"),
    stringsAsFactors = FALSE
  )
  write.csv(peak_df, tmp_csv)

  si <- data.frame(
    sample_id = c("S1", "S2"),
    class     = c("CTL", "TREAT"),
    group     = c("CTL", "TREAT"),
    stringsAsFactors = FALSE
  )

  obj <- build_mass_dataset(tmp_csv, sample_info = si)
  si_out <- massdataset::extract_sample_info(obj)

  expect_equal(si_out$sample_id, c("S1", "S2"))
  expect_equal(si_out$class,     c("CTL", "TREAT"))
})


## ========================= impute_filter_normalize =========================

test_that("impute_filter_normalize: 低强度feature被删除 / features below intensity_floor are removed", {
  skip_if_not_installed("massdataset")

  ## 构造一个含低强度feature的mass_dataset
  ## Build a mass_dataset with one below-floor feature
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)

  peak_df <- data.frame(
    mz  = c(100.01, 200.02, 300.03),
    rt  = c(10.0, 20.0, 30.0),
    S1  = c(5000, 6000,  500),   ## feat3 低于1000 / feat3 below floor
    S2  = c(5100, 5900,  200),
    S3  = c(4900, 6100,  300),
    row.names = c("feat1", "feat2", "feat3"),
    stringsAsFactors = FALSE
  )
  write.csv(peak_df, tmp_csv)

  obj <- build_mass_dataset(tmp_csv)
  obj_proc <- impute_filter_normalize(obj, intensity_floor = 1000, mv_method = "min")

  vi_out <- massdataset::extract_variable_info(obj_proc)
  ## feat3 应被过滤掉 / feat3 should be removed
  expect_false("feat3" %in% vi_out$variable_id)
  ## feat1, feat2 应保留 / feat1 and feat2 should remain
  expect_true("feat1" %in% vi_out$variable_id)
  expect_true("feat2" %in% vi_out$variable_id)
})

test_that("impute_filter_normalize: 返回mass_dataset对象 / returns a mass_dataset object", {
  skip_if_not_installed("massdataset")

  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)

  peak_df <- data.frame(
    mz  = c(100.01, 200.02),
    rt  = c(10.0, 20.0),
    S1  = c(5000, 6000),
    S2  = c(5100, 5900),
    S3  = c(4900, 6100),
    row.names = c("feat1", "feat2"),
    stringsAsFactors = FALSE
  )
  write.csv(peak_df, tmp_csv)

  obj      <- build_mass_dataset(tmp_csv)
  obj_proc <- impute_filter_normalize(obj, intensity_floor = 100, mv_method = "min")

  expect_s4_class(obj_proc, "mass_dataset")
})

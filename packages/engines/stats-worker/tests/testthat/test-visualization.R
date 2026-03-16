##############################################################################
##  stats-worker/tests/testthat/test-visualization.R
##  测试 visualization.R 中的绘图函数
##  Tests for plotting functions in visualization.R
##
##  theme_nature 和 plot_volcano_nature 依赖 ggplot2。
##  save_nature_plot 还依赖 cairo_pdf 设备（需 Cairo 包）。
##  theme_nature and plot_volcano_nature require ggplot2.
##  save_nature_plot also requires the cairo_pdf device (Cairo package).
##############################################################################

## visualization.R 内部会 source config.R
## visualization.R sources config.R internally
source("../../R/visualization.R")

## ========================= theme_nature =========================

test_that("theme_nature: 返回ggplot主题对象 / returns a ggplot theme object", {
  skip_if_not_installed("ggplot2")

  th <- theme_nature()
  expect_s3_class(th, "theme")
})

test_that("theme_nature: subfig_mode=TRUE 字号增大3pt / subfig_mode increases base_size by 3", {
  skip_if_not_installed("ggplot2")

  th_normal <- theme_nature(base_size = 8, subfig_mode = FALSE)
  th_subfig <- theme_nature(base_size = 8, subfig_mode = TRUE)

  ## axis.title font size 应为 base_size+1 / axis.title = base_size + 1
  normal_axis_size <- th_normal$axis.title$size   ## 9
  subfig_axis_size <- th_subfig$axis.title$size   ## 12

  expect_equal(subfig_axis_size - normal_axis_size, 3L)
})

test_that("theme_nature: 网格线被移除 / major and minor grid lines are blank", {
  skip_if_not_installed("ggplot2")

  th <- theme_nature()
  expect_true(inherits(th$panel.grid.major, "element_blank"))
  expect_true(inherits(th$panel.grid.minor, "element_blank"))
})

test_that("theme_nature: 默认base_size=8 / default base_size is 8", {
  skip_if_not_installed("ggplot2")

  th <- theme_nature()
  ## plot.title size 应为 base_size+2 = 10
  expect_equal(th$plot.title$size, 10L)
})


## ========================= save_nature_plot =========================

test_that("save_nature_plot: 生成 .pdf 和 .tiff 两个文件 / creates both .pdf and .tiff files", {
  skip_if_not_installed("ggplot2")

  ## 需要 cairo_pdf 设备 / needs cairo_pdf device
  skip_if_not(capabilities("cairo"), "cairo not available")

  tmp_dir  <- tempdir()
  tmp_base <- file.path(tmp_dir, "test_save_nature_plot")

  ## 创建一个最简单的ggplot对象 / create minimal ggplot
  p <- ggplot2::ggplot(data.frame(x = 1, y = 1),
                       ggplot2::aes(x, y)) +
    ggplot2::geom_point()

  save_nature_plot(p, tmp_base, width = 3, height = 3)

  expect_true(file.exists(paste0(tmp_base, ".pdf")))
  expect_true(file.exists(paste0(tmp_base, ".tiff")))

  ## 清理 / cleanup
  unlink(paste0(tmp_base, ".pdf"))
  unlink(paste0(tmp_base, ".tiff"))
})


## ========================= plot_volcano_nature =========================

## 构造最小的limma topTable结果用于火山图测试
## Build minimal limma topTable result for volcano plot tests
.make_volcano_df <- function(n = 30L) {
  set.seed(7L)
  data.frame(
    logFC     = runif(n, -1.5, 1.5),
    adj.P.Val = c(runif(5, 0.001, 0.04),   ## 5个显著 / 5 significant
                  runif(n - 5, 0.06, 1.0)),
    P.Value   = c(runif(5, 0.001, 0.04),
                  runif(n - 5, 0.06, 1.0)),
    row.names = paste0("feat", seq_len(n)),
    stringsAsFactors = FALSE
  )
}

test_that("plot_volcano_nature: 返回ggplot对象 / returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  skip_if_not(capabilities("cairo"), "cairo not available")

  df  <- .make_volcano_df()
  tmp <- file.path(tempdir(), "test_volcano")

  p <- plot_volcano_nature(
    res     = df,
    prefix  = tmp,
    alpha   = 0.05,
    fc_cut  = 0.176,
    colors  = volcano_colors,
    p_col   = "adj.P.Val"
  )

  expect_s3_class(p, "gg")

  unlink(paste0(tmp, ".pdf"))
  unlink(paste0(tmp, ".tiff"))
})

test_that("plot_volcano_nature: Significance列分类正确 / Significance column categorized correctly", {
  skip_if_not_installed("ggplot2")
  skip_if_not(capabilities("cairo"), "cairo not available")

  df <- .make_volcano_df()

  ## 手动计算期望分类 / manually compute expected classification
  expected_sig <- ifelse(
    df$adj.P.Val < 0.05 & abs(df$logFC) > 0.176,
    ifelse(df$logFC > 0, "Up", "Down"),
    "Not"
  )

  tmp <- file.path(tempdir(), "test_volcano_sig")
  p   <- plot_volcano_nature(
    res = df, prefix = tmp, alpha = 0.05, fc_cut = 0.176,
    colors = volcano_colors, p_col = "adj.P.Val"
  )

  ## ggplot的数据层包含Significance列
  ## The ggplot data layer contains the Significance column
  plot_data <- p$data
  expect_true("Significance" %in% colnames(plot_data))
  expect_equal(as.character(plot_data$Significance), expected_sig)

  unlink(paste0(tmp, ".pdf"))
  unlink(paste0(tmp, ".tiff"))
})

test_that("plot_volcano_nature: 使用P.Value列也能正常运行 / works with P.Value column", {
  skip_if_not_installed("ggplot2")
  skip_if_not(capabilities("cairo"), "cairo not available")

  df  <- .make_volcano_df()
  tmp <- file.path(tempdir(), "test_volcano_pval")

  p <- plot_volcano_nature(
    res = df, prefix = tmp, alpha = 0.05, fc_cut = 0.176,
    colors = volcano_colors, p_col = "P.Value"
  )

  expect_s3_class(p, "gg")

  unlink(paste0(tmp, ".pdf"))
  unlink(paste0(tmp, ".tiff"))
})

test_that("plot_volcano_nature: subfig_mode=TRUE 不出错 / subfig_mode=TRUE runs without error", {
  skip_if_not_installed("ggplot2")
  skip_if_not(capabilities("cairo"), "cairo not available")

  df  <- .make_volcano_df()
  tmp <- file.path(tempdir(), "test_volcano_subfig")

  expect_no_error(
    plot_volcano_nature(
      res = df, prefix = tmp, alpha = 0.05, fc_cut = 0.176,
      colors = volcano_colors, p_col = "adj.P.Val", subfig_mode = TRUE
    )
  )

  unlink(paste0(tmp, ".pdf"))
  unlink(paste0(tmp, ".tiff"))
})

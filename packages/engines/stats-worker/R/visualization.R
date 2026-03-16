##############################################################################
##  stats-worker/R/visualization.R
##  Nature级别绘图函数 / Nature-quality plotting functions
##
##  提供统一绘图主题、高质量保存和火山图生成。
##  Provides unified plot theme, high-quality save helper, and volcano plot.
##  Depends on: config.R (must be sourced before this file)
##############################################################################

source(file.path(dirname(sys.frame(1)$ofile), "config.R"))


## ========================= 2.1 统一主题 / Unified Theme =========================

## Nature论文级别ggplot2主题
## Nature publication-quality ggplot2 theme
## @param base_size  基础字号 / base font size in pt (default 8)
## @param subfig_mode 小子图模式：TRUE时字号+3 / small sub-figure mode: adds 3pt when TRUE
theme_nature <- function(base_size = 8, subfig_mode = FALSE) {
  if (isTRUE(subfig_mode)) base_size <- base_size + 3
  theme_bw(base_size = base_size) %+replace%
    theme(
      text             = element_text(family = "Arial", color = "black"),
      axis.title       = element_text(size = base_size + 1, face = "bold"),
      axis.text        = element_text(size = base_size, color = "black"),
      plot.title       = element_text(size = base_size + 2, face = "bold", hjust = 0),
      legend.title     = element_text(size = base_size, face = "bold"),
      legend.text      = element_text(size = base_size - 1),
      strip.text       = element_text(size = base_size, face = "bold"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", linewidth = 0.6),
      axis.ticks       = element_line(color = "black", linewidth = 0.4),
      plot.margin      = margin(8, 8, 8, 8, "pt"),
      legend.key.size  = unit(0.35, "cm"),
      aspect.ratio     = 1
    )
}


## ========================= 2.3 高质量保存 / High-quality Save =========================

## 同时输出PDF矢量和300 DPI TIFF / Outputs both vector PDF and 300 DPI TIFF
## @param plot_obj  ggplot对象 / ggplot object
## @param filename  不含扩展名的完整路径 / full path without extension
## @param width     宽度(英寸) / width in inches (default 7)
## @param height    高度(英寸) / height in inches (default 7)
save_nature_plot <- function(plot_obj, filename, width = 7, height = 7) {
  ggsave(paste0(filename, ".pdf"), plot = plot_obj,
         width = width, height = height, units = "in", device = cairo_pdf)
  ggsave(paste0(filename, ".tiff"), plot = plot_obj,
         width = width, height = height, units = "in", dpi = 300,
         compression = "lzw")
}


## ========================= 火山图 / Volcano Plot =========================

## Nature级别火山图 / Nature-quality volcano plot
## @param res        limma topTable结果data.frame (含logFC和p值列)
##                   limma topTable result data.frame (must contain logFC + p-value columns)
## @param prefix     输出文件路径前缀（不含扩展名）/ output path prefix (no extension)
## @param alpha      显著性阈值 / significance threshold (e.g. 0.05)
## @param fc_cut     log10 FC阈值 / log10 FC cutoff (e.g. 0.176 for 1.5x)
## @param colors     命名色向量 c(Down=, Not=, Up=) / named color vector
## @param p_col      用于显著性判断的列名 / column name for significance ("adj.P.Val" or "P.Value")
## @param subfig_mode 小子图字体放大模式 / small sub-figure font-enlargement mode
## @return 不可见地返回ggplot对象 / invisibly returns the ggplot object
plot_volcano_nature <- function(res,
                                prefix,
                                alpha,
                                fc_cut,
                                colors,
                                p_col      = "adj.P.Val",
                                subfig_mode = FALSE) {
  res$Significance <- ifelse(
    res[[p_col]] < alpha & abs(res$logFC) > fc_cut,
    ifelse(res$logFC > 0, "Up", "Down"),
    "Not"
  )
  res$Significance <- factor(res$Significance, levels = c("Down", "Not", "Up"))

  n_up   <- sum(res$Significance == "Up")
  n_down <- sum(res$Significance == "Down")

  p <- ggplot(res, aes(logFC, -log10(.data[[p_col]]))) +
    geom_point(aes(color = Significance), size = 1.5, alpha = 0.7) +
    scale_color_manual(
      values = colors,
      labels = c(paste0("Down (", n_down, ")"), "NS", paste0("Up (", n_up, ")"))
    ) +
    geom_vline(xintercept = c(-fc_cut, fc_cut),
               lty = 2, color = "grey40", linewidth = 0.4) +
    geom_hline(yintercept = -log10(alpha),
               lty = 2, color = "grey40", linewidth = 0.4) +
    labs(
      x     = expression("log"[10]*"(Fold Change)"),
      y     = bquote("-log"[10]*"("*.(p_col)*")"),
      color = ""
    ) +
    theme_nature(base_size = 9, subfig_mode = subfig_mode) +
    theme(legend.position  = c(0.15, 0.88),
          legend.background = element_blank())

  save_nature_plot(p, prefix, width = 5, height = 5)
  invisible(p)
}

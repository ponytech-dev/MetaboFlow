##############################################################################
##  MetaboFlow v1.0 — 非靶向代谢组学四工作流集成分析系统
##  MetaboFlow v1.0 — Untargeted Metabolomics Quad-Workflow Integrated Pipeline
##
##  工作流 / Workflows:
##    1. tidymass enrich_hmdb  → SMPDB通路富集 / SMPDB Pathway Enrichment (ORA)
##    2. MetaboAnalystR MSEA   → 代谢物集富集分析 / Metabolite Set Enrichment (ORA)
##    3. KEGGREST + Fisher     → KEGG通路富集分析 / KEGG Pathway Enrichment (ORA)
##    4. globaltest            → 定量富集分析 / Quantitative Enrichment Analysis (QEA)
##
##  所有输出图表按 Nature 论文级别标准渲染：
##  All figures rendered to Nature publication standards:
##    - ggsci NPG/Lancet 配色 / color palettes
##    - PDF矢量输出 + 300 DPI TIFF备份 / vector PDF + 300 DPI TIFF
##    - 7×7英寸单栏 或 14×7英寸双栏 / single-column or double-column
##    - Arial字体, 7-9pt正文 / Arial font, 7-9pt body text
##
##  系统要求 / System Requirements:
##    - R >= 4.5.0 (required by tidymass)
##    - macOS / Linux / Windows 10+
##    - RAM >= 8 GB (16 GB recommended)
##    - Internet connection for first-run package installation
##############################################################################

## ========================= 0. 依赖安装 / Dependency Installation =========================
## 此段代码自动检测并安装所有必需包
## This section auto-detects and installs all required packages

cat("========== MetaboFlow v1.0 启动 / Initializing ==========\n")

## --- 0.1 基础包管理器 / Base package manager ---
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

## --- 0.2 辅助安装函数 / Helper install functions ---
install_cran <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  安装/Installing ", pkg, "...\n"))
    tryCatch(install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE),
             error = function(e) cat(paste0("    警告/Warning: ", pkg, " 安装失败/failed\n")))
  }
}

install_bioc <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  安装/Installing ", pkg, " (Bioconductor)...\n"))
    tryCatch(BiocManager::install(pkg, update = FALSE, ask = FALSE, quiet = TRUE),
             error = function(e) cat(paste0("    警告/Warning: ", pkg, " 安装失败/failed\n")))
  }
}

## --- 0.3 CRAN包 / CRAN packages ---
## 数据处理 + 绘图 + 统计 + IO 完整列表 / Full list: data, plotting, stats, IO
cran_pkgs <- c(
  ## 核心数据处理 / Core data processing
  "tidyverse", "dplyr", "tidyr", "readr", "stringr", "purrr", "tibble", "forcats",
  ## IO
  "openxlsx", "readxl",
  ## 绘图 / Plotting
  "ggplot2", "ggrepel", "pheatmap", "ggpubr", "ggsci", "patchwork",
  "scales", "RColorBrewer", "viridis", "gridExtra",
  ## 图形设备 / Graphics device
  "Cairo",
  ## 安装工具 / Install tools
  "remotes",
  ## MetaboAnalystR运行时依赖 / MetaboAnalystR runtime deps
  "qs", "survival",
  ## 统计辅助 / Statistical helpers
  "broom"
)
invisible(lapply(cran_pkgs, install_cran))

## --- 0.4 Bioconductor包 / Bioconductor packages ---
## 色谱峰提取 + 差异分析 + 通路分析 + 富集分析 完整列表
bioc_pkgs <- c(
  ## 差异分析 / Differential analysis
  "Biobase", "limma",
  ## 通路分析 / Pathway analysis
  "KEGGREST", "globaltest", "KEGGgraph",
  ## XCMS色谱峰处理 / XCMS peak processing
  "xcms", "MSnbase", "BiocParallel",
  ## 数据预处理 / Data preprocessing
  "impute", "pcaMethods", "preprocessCore", "genefilter", "sva",
  ## 统计/富集 / Stats/enrichment
  "multtest", "edgeR", "fgsea",
  ## 图结构 / Graph structures
  "RBGL", "Rgraphviz"
)
invisible(lapply(bioc_pkgs, install_bioc))

## --- 0.5 tidymass / tidymass suite ---
if (!requireNamespace("tidymass", quietly = TRUE)) {
  cat("  安装tidymass（可能需要几分钟）/ Installing tidymass (may take minutes)...\n")
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  tryCatch(
    remotes::install_gitlab("tidymass/tidymass", upgrade = "never", quiet = TRUE),
    error = function(e) {
      cat("  tidymass 安装失败 / installation failed:", conditionMessage(e), "\n")
      cat("  WF1将被跳过 / WF1 will be skipped\n")
    }
  )
}

## --- 0.6 MetaboAnalystR / MetaboAnalystR ---
if (!requireNamespace("MetaboAnalystR", quietly = TRUE)) {
  cat("  安装MetaboAnalystR... / Installing MetaboAnalystR...\n")
  cat("  注意：首次安装可能需要10-20分钟 / Note: first install may take 10-20 min\n")

  metabo_cran <- c("Rserve", "RColorBrewer", "xtable", "fitdistrplus",
                   "som", "ROCR", "RJSONIO", "gplots", "e1071", "caTools",
                   "igraph", "randomForest", "caret", "pls", "lattice")
  invisible(lapply(metabo_cran, install_cran))

  bioc_deps <- c("GlobalAncova", "SSPA", "MAIT")
  invisible(lapply(bioc_deps, install_bioc))

  tryCatch({
    remotes::install_github("xia-lab/MetaboAnalystR", build_vignettes = FALSE,
                             dependencies = FALSE, quiet = TRUE)
    cat("  MetaboAnalystR 安装成功 / installed successfully\n")
  }, error = function(e) {
    cat("  MetaboAnalystR 安装失败 / installation failed\n")
    cat("  WF2将被跳过 / WF2 will be skipped\n")
  })
}

## --- 0.7 加载所有包 / Load all packages ---
suppressPackageStartupMessages({
  library(tidyverse)
  library(openxlsx)
  library(ggplot2)
  library(ggrepel)
  library(ggsci)
  library(limma)
  library(pheatmap)
  library(ggpubr)
  library(patchwork)
})

## tidymass 可选加载 / optional load
has_tidymass <- requireNamespace("tidymass", quietly = TRUE)
if (has_tidymass) {
  suppressPackageStartupMessages(library(tidymass))
  cat("  tidymass 已加载 / loaded\n")
} else {
  ## 尝试加载子包 / Try loading subpackages
  if (requireNamespace("Biobase", quietly = TRUE)) library(Biobase)
  if (requireNamespace("massdataset", quietly = TRUE)) library(massdataset)
  cat("  tidymass 未安装，WF1跳过 / not installed, WF1 skipped\n")
}

## MetaboAnalystR 可选加载 / optional load
has_metaboanalyst <- requireNamespace("MetaboAnalystR", quietly = TRUE)
if (has_metaboanalyst) {
  library(MetaboAnalystR)
  cat("  MetaboAnalystR 已加载 / loaded\n")
} else {
  cat("  MetaboAnalystR 未安装，WF2跳过 / not installed, WF2 skipped\n")
}

## Biobase 兼容性修复 / Biobase compatibility fix
if (requireNamespace("Biobase", quietly = TRUE) && !methods::isClass("NAnnotatedDataFrame")) {
  methods::setClass("NAnnotatedDataFrame", contains = "AnnotatedDataFrame")
}

cat("========== 所有依赖就绪 / All dependencies ready ==========\n\n")


## ========================= 1. 用户参数区 / User Parameters =========================
## ▼▼▼ 以下参数需要用户根据实验设计修改 ▼▼▼
## ▼▼▼ Modify parameters below according to your experiment ▼▼▼

WORK_DIR       <- "path/to/your/data"   # 工作路径 / working directory
POLARITY       <- "positive"     # 极性模式 / ionization polarity: "positive" or "negative"
LOGFC_CUTOFF   <- 0.176          # log10 FC阈值 / log10 FC threshold (0.176=1.5x, 0.301=2x)
ALPHA          <- 0.05           # FDR校正显著性阈值 / FDR significance threshold
ORGANISM       <- "dre"          # MetaboAnalyst物种代码 / organism code (dre=zebrafish, hsa=human, mmu=mouse)
MS1_PPM        <- 15             # MS1质量容差ppm / MS1 mass tolerance in ppm
PEAK_WIDTH     <- c(5, 30)       # 峰宽范围(秒) / peak width range (seconds)
SN_THRESH      <- 5              # 信噪比阈值 / signal-to-noise threshold
NOISE_LEVEL    <- 500            # 噪声水平 / noise level
MIN_FRACTION   <- 0.5            # 最小样本检出率 / minimum fraction of samples
N_THREADS      <- 10             # 并行线程数 / number of threads
INTENSITY_FLOOR <- 1000          # 最低强度阈值 / minimum intensity floor
NORM_METHOD    <- "median"       # 归一化方法 / normalization method ("median","mean","sum","pqn")
CONTROL_GROUP  <- "control"      # 对照组名称 / control group name (must match filename prefix)
MODEL_GROUP    <- "MethiocarbA"  # 模型组名称 / model group name (must match filename prefix)

## 数据库路径 / Database paths
DB_DIR <- "path/to/your/inhouse_database"

## 通路图设置 / Pathway plot settings
TOP_N_PATHWAYS  <- 0          # 图中最多显示通路数 / Max pathways in plot (0=all significant)
PATHWAY_FIG_W   <- 7          # 通路图宽度(英寸) / Pathway figure width (inches)
PATHWAY_FIG_H   <- 5          # 通路图高度(英寸) / Pathway figure height (inches)
SUBFIG_MODE     <- FALSE      # 小子图模式：更大字体+紧凑布局 / Small sub-figure mode
FILTER_NONSPECIFIC <- TRUE    # 过滤非特异性通路 / Filter non-specific pathways (TRUE/FALSE)

## ▲▲▲ 参数区结束 ▲▲▲


## ========================= 2. Nature级别绘图主题 / Nature-Quality Plot Theme =========================

## --- 2.1 统一主题 / Unified theme ---
## SUBFIG_MODE=TRUE时自动放大字体以适应论文小子图 / Auto-enlarge font for paper sub-figures
theme_nature <- function(base_size = 8) {
  if (exists("SUBFIG_MODE") && isTRUE(SUBFIG_MODE)) base_size <- base_size + 3
  theme_bw(base_size = base_size) %+replace%
    theme(
      text = element_text(family = "Arial", color = "black"),
      axis.title = element_text(size = base_size + 1, face = "bold"),
      axis.text = element_text(size = base_size, color = "black"),
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0),
      legend.title = element_text(size = base_size, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      strip.text = element_text(size = base_size, face = "bold"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.6),
      axis.ticks = element_line(color = "black", linewidth = 0.4),
      plot.margin = margin(8, 8, 8, 8, "pt"),
      legend.key.size = unit(0.35, "cm"),
      aspect.ratio = 1
    )
}

## --- 2.2 Nature配色方案 / Nature color palettes ---
nature_colors <- c(
  "#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F",
  "#8491B4", "#91D1C2", "#DC0000", "#7E6148", "#B09C85"
)
pathway_gradient <- c("#FDE725", "#35B779", "#31688E", "#440154")
volcano_colors <- c(Down = "#3C5488", Not = "#D3D3D3", Up = "#E64B35")
heatmap_colors <- colorRampPalette(c("#3C5488", "white", "#E64B35"))(100)

## --- 2.3 高质量保存函数 / High-quality save function ---
save_nature_plot <- function(plot_obj, filename, width = 7, height = 7) {
  ggsave(paste0(filename, ".pdf"), plot = plot_obj,
         width = width, height = height, units = "in", device = cairo_pdf)
  ggsave(paste0(filename, ".tiff"), plot = plot_obj,
         width = width, height = height, units = "in", dpi = 300,
         compression = "lzw")
}


## ========================= 2.5 HMDB ID格式统一 / HMDB ID Normalization =========================
normalize_hmdb <- function(ids) {
  ids <- ids[!is.na(ids) & ids != ""]
  ids <- ifelse(
    nchar(ids) == 11 & grepl("^HMDB\\d{5}$", ids),
    paste0("HMDB00", substring(ids, 5)),
    ids
  )
  unique(ids)
}


## ========================= 2.6 非特异性通路过滤 / Non-specific Pathway Filter =========================
## 这些通路过于宽泛，几乎在任何代谢组数据中都会显著，属于假阳性
## These pathways are too broad — they appear significant in virtually any metabolomics dataset

NONSPECIFIC_KEYWORDS <- c(
  "Metabolic pathways",
  "Biosynthesis of secondary metabolites",
  "Biosynthesis of amino acids",
  "Carbon metabolism",
  "2-Oxocarboxylic acid metabolism",
  "Biosynthesis of cofactors",
  "ABC transporters",
  "Protein digestion and absorption",
  "Mineral absorption",
  "Aminoacyl-tRNA biosynthesis"
)

## 最大通路代谢物数阈值：超过此值的通路被视为非特异性
## Pathways with more metabolites than this threshold are considered non-specific
NONSPECIFIC_SIZE_CUTOFF <- 150

## 通路过滤函数 / Pathway filter function
## 当 FILTER_NONSPECIFIC=TRUE 时过滤非特异性通路，否则原样返回
## When FILTER_NONSPECIFIC=TRUE, removes non-specific pathways; otherwise returns as-is
## Returns: list(all=原始显著, filtered=过滤后)
filter_nonspecific <- function(df, name_col = "pathway_name", size_col = NULL) {
  if (nrow(df) == 0) return(list(all = df, filtered = df))

  ## 开关检查 / Check toggle
  if (!exists("FILTER_NONSPECIFIC") || !isTRUE(FILTER_NONSPECIFIC)) {
    return(list(all = df, filtered = df))
  }

  ## 关键词匹配过滤 / Keyword match filter
  blacklist_hit <- sapply(df[[name_col]], function(pw) {
    any(sapply(NONSPECIFIC_KEYWORDS, function(kw) grepl(kw, pw, ignore.case = TRUE)))
  })

  ## 通路大小过滤 / Size-based filter
  size_hit <- rep(FALSE, nrow(df))
  if (!is.null(size_col) && size_col %in% colnames(df)) {
    size_hit <- df[[size_col]] > NONSPECIFIC_SIZE_CUTOFF
  }

  keep <- !(blacklist_hit | size_hit)
  list(all = df, filtered = df[keep, ])
}

## 通路图数据准备函数 / Prepare plot data respecting TOP_N_PATHWAYS
prep_pathway_plot <- function(df, n_col = NULL) {
  if (nrow(df) == 0) return(df)
  n <- if (exists("TOP_N_PATHWAYS") && TOP_N_PATHWAYS > 0) TOP_N_PATHWAYS else nrow(df)
  n <- min(n, nrow(df))
  df[seq_len(n), ]
}


## ========================= 3. 数据处理 / Data Processing =========================

rm(list = setdiff(ls(), c("WORK_DIR","POLARITY","LOGFC_CUTOFF","ALPHA","ORGANISM",
                           "MS1_PPM","PEAK_WIDTH","SN_THRESH","NOISE_LEVEL",
                           "MIN_FRACTION","N_THREADS","INTENSITY_FLOOR","NORM_METHOD",
                           "CONTROL_GROUP","MODEL_GROUP","DB_DIR",
                           "TOP_N_PATHWAYS","PATHWAY_FIG_W","PATHWAY_FIG_H","SUBFIG_MODE","FILTER_NONSPECIFIC",
                           "NONSPECIFIC_KEYWORDS","NONSPECIFIC_SIZE_CUTOFF",
                           "theme_nature","nature_colors","pathway_gradient",
                           "volcano_colors","heatmap_colors","save_nature_plot",
                           "has_metaboanalyst","has_tidymass","normalize_hmdb",
                           "filter_nonspecific","prep_pathway_plot")))

setwd(WORK_DIR)

cat("\n========== Step 1: 特征提取 / Feature Extraction ==========\n")

massprocesser::process_data(
  path = "./",
  polarity = POLARITY,
  ppm = MS1_PPM,
  peakwidth = PEAK_WIDTH,
  snthresh = SN_THRESH,
  noise = NOISE_LEVEL,
  threads = N_THREADS,
  output_tic = FALSE,
  output_bpc = FALSE,
  output_rt_correction_plot = FALSE,
  min_fraction = MIN_FRACTION,
  fill_peaks = FALSE
)

setwd("./Result")

## --- 构建mass_dataset对象 / Build mass_dataset object ---
raw_data <- read.csv("peak_table_for_cleaning.csv", row.names = 1, header = TRUE)
variable_info <- raw_data[, c("mz", "rt")] %>% mutate(variable_id = rownames(raw_data))
variable_info <- variable_info[, c("variable_id", "mz", "rt")]
rownames(variable_info) <- seq_len(nrow(raw_data))
expression_data <- raw_data[, !colnames(raw_data) %in% c("mz", "rt")]

sample_info <- data.frame(
  sample_id = colnames(expression_data),
  class = gsub("[0-9]", "", colnames(expression_data)),
  group = gsub("[0-9]", "", colnames(expression_data))
)

object <- create_mass_dataset(
  expression_data = expression_data,
  sample_info = sample_info,
  variable_info = variable_info
)

## --- 缺失值填充 / Missing value imputation ---
object <- impute_mv(object = object, method = "knn")

## --- 强度过滤 / Intensity filtering ---
keep_ids <- rownames(object@expression_data)[
  apply(object@expression_data, 1, function(row) !any(row < INTENSITY_FLOOR))
]
object <- object %>%
  activate_mass_dataset("variable_info") %>%
  dplyr::filter(variable_id %in% keep_ids)

## --- 归一化 / Normalization ---
object2 <- normalize_data(object, method = NORM_METHOD)

group <- gsub("[0-9]", "", colnames(object2@expression_data))
cat("  样本分组 / Sample groups: ", paste(unique(group), collapse = ", "), "\n")
cat("  Feature数量 / Feature count:", nrow(object2@expression_data), "\n")


## ========================= 4. PCA / PCA Analysis =========================
cat("\n========== Step 2: PCA分析 / PCA Analysis ==========\n")

iris_input <- t(object2@expression_data)
pca1 <- prcomp(iris_input, scale. = TRUE)
df1 <- as.data.frame(pca1$x)
df1$group <- group
summ1 <- summary(pca1)
xlab1 <- paste0("PC1 (", round(summ1$importance[2, 1] * 100, 1), "%)")
ylab1 <- paste0("PC2 (", round(summ1$importance[2, 2] * 100, 1), "%)")

p_pca <- ggplot(df1, aes(x = PC1, y = PC2, color = group, fill = group)) +
  stat_ellipse(type = "norm", geom = "polygon", alpha = 0.15,
               color = NA, level = 0.80) +
  geom_point(size = 3, shape = 21, color = "black", stroke = 0.5) +
  scale_fill_manual(values = nature_colors) +
  scale_color_manual(values = nature_colors) +
  labs(x = xlab1, y = ylab1, color = "Group", fill = "Group") +
  theme_nature(base_size = 9) +
  guides(fill = guide_legend(override.aes = list(size = 4)))

save_nature_plot(p_pca, "PCA_scores", width = 5, height = 5)
cat("  PCA图已保存 / PCA plot saved\n")


## ========================= 5. 差异分析 / Differential Analysis =========================
cat("\n========== Step 3: 差异分析 / Differential Analysis ==========\n")
dir.create("差异代谢峰", showWarnings = FALSE)

## --- limma差异分析 / limma differential analysis ---
run_limma <- function(data_ctl, data_treat, feature_names) {
  ana <- cbind(data_ctl, data_treat)
  rownames(ana) <- feature_names
  type_vec <- c(rep("CTL", ncol(data_ctl)), rep("TREAT", ncol(data_treat)))
  design <- model.matrix(~ 0 + factor(type_vec))
  colnames(design) <- c("CTL", "TREAT")
  fit <- lmFit(as.data.frame(ana), design = design)
  fit2 <- contrasts.fit(fit, makeContrasts(TREAT - CTL, levels = design))
  fit2 <- eBayes(fit2)
  Diff <- topTable(fit2, adjust = "fdr", number = nrow(ana))

  ## 自动选择显著性列 / Auto-select significance column
  ## 小样本(n<=3)时adj.P.Val可能全>0.05，退回P.Value
  p_col <- if (any(Diff$adj.P.Val < ALPHA)) "adj.P.Val" else "P.Value"
  sig <- Diff[abs(Diff$logFC) >= LOGFC_CUTOFF & Diff[[p_col]] < ALPHA, ]

  list(all = Diff, sig = sig, p_col = p_col)
}

## --- Nature级别火山图 / Nature-quality volcano plot ---
plot_volcano_nature <- function(Diff, title_text, filename, p_col = "adj.P.Val") {
  Diff$Significance <- ifelse(
    Diff[[p_col]] < ALPHA & abs(Diff$logFC) > LOGFC_CUTOFF,
    ifelse(Diff$logFC > 0, "Up", "Down"), "Not"
  )
  Diff$Significance <- factor(Diff$Significance, levels = c("Down", "Not", "Up"))

  n_up <- sum(Diff$Significance == "Up")
  n_down <- sum(Diff$Significance == "Down")

  p <- ggplot(Diff, aes(logFC, -log10(.data[[p_col]]))) +
    geom_point(aes(color = Significance), size = 1.5, alpha = 0.7) +
    scale_color_manual(values = volcano_colors,
                       labels = c(paste0("Down (", n_down, ")"),
                                  "NS",
                                  paste0("Up (", n_up, ")"))) +
    geom_vline(xintercept = c(-LOGFC_CUTOFF, LOGFC_CUTOFF),
               lty = 2, color = "grey40", linewidth = 0.4) +
    geom_hline(yintercept = -log10(ALPHA),
               lty = 2, color = "grey40", linewidth = 0.4) +
    labs(x = expression("log"[10]*"(Fold Change)"),
         y = bquote("-log"[10]*"("*.(p_col)*")"),
         title = title_text, color = "") +
    theme_nature(base_size = 9) +
    theme(legend.position = c(0.15, 0.88),
          legend.background = element_blank())

  save_nature_plot(p, filename, width = 5, height = 5)
  return(p)
}

## --- 执行差异分析 / Execute differential analysis ---
con <- group == CONTROL_GROUP
model_grp <- group == MODEL_GROUP
PCA_data <- as.data.frame(object2@expression_data)
log_PCA_data <- log10(PCA_data)

if (any(con)) {
  res_model <- run_limma(log_PCA_data[, con], log_PCA_data[, model_grp],
                         rownames(object2@expression_data))
  write.csv(res_model$sig, "差异代谢峰/Model差异峰.csv", row.names = FALSE)
  plot_volcano_nature(res_model$all, "Model vs. Control",
                      "差异代谢峰/Model差异代谢峰", p_col = res_model$p_col)
  cat("  Model组: ", nrow(res_model$sig), "个差异代谢峰 / differential features\n")
  cat("  使用/Using:", res_model$p_col, "作为显著性列\n")
}

other <- group != CONTROL_GROUP & group != MODEL_GROUP
if (any(other)) {
  CTL_ref <- log_PCA_data[, model_grp]
  for (grp_name in unique(group[other])) {
    treat <- log_PCA_data[, group == grp_name]
    res <- run_limma(CTL_ref, treat, rownames(object2@expression_data))
    write.csv(res$sig, paste0("差异代谢峰/", grp_name, "差异峰.csv"), row.names = FALSE)
    plot_volcano_nature(res$all, paste0(grp_name, " vs. Model"),
                        paste0("差异代谢峰/", grp_name, "差异代谢峰"), p_col = res$p_col)
    cat("  ", grp_name, "组:", nrow(res$sig), "个差异代谢峰\n")
  }
}


## ========================= 6. 代谢物注释 / Metabolite Annotation =========================
cat("\n========== Step 4: 代谢物注释 / Metabolite Annotation ==========\n")

load(file.path(DB_DIR, "inhouse_Metabolite.database"))
load(file.path(DB_DIR, "hmdb_ms2_merged.rda"))
load(file.path(DB_DIR, "massbank_ms2_merged.rda"))
load(file.path(DB_DIR, "mona_ms2_merged.rda"))
load(file.path(DB_DIR, "orbitrap_database0.0.3.rda"))

object1 <- annotate_metabolites_mass_dataset(
  object = object2, ms1.match.ppm = MS1_PPM, rt.match.tol = 6000,
  polarity = POLARITY, database = inhouse_Metabolite.database)

for (db in list(hmdb_ms2, massbank_ms2, mona_ms2, orbitrap_database0.0.3)) {
  object1 <- annotate_metabolites_mass_dataset(
    object = object1, ms1.match.ppm = MS1_PPM, rt.match.tol = 90000,
    polarity = POLARITY, database = db)
}

app <- extract_annotation_table(object1)
mzrt <- read.csv("Peak_table.csv")[, 1:7]
colnames(mzrt) <- c("variable_id", "mz", "mzmin", "mzmax", "rt", "rtmin", "rtmax")
app3 <- left_join(app, mzrt, by = "variable_id") %>%
  dplyr::select(variable_id, mz, rt, mzmin, mzmax, rtmin, rtmax, everything())
write.csv(app3, "所有代谢物.csv", row.names = FALSE)
cat("  注释完成，共", nrow(app3), "条注释记录 / annotation records\n")


## ========================= 7. 四工作流集成 / Quad-Workflow Integration =========================
cat("\n========== Step 5: 四工作流通路分析 / Quad-Workflow Pathway Analysis ==========\n")
dir.create("差异代谢物", showWarnings = FALSE)

## --- 主执行循环 / Main execution loop ---
files <- list.files("差异代谢峰", pattern = "\\.csv$", full.names = FALSE)

for (fi in seq_along(files)) {
  diff_data <- read.csv(paste0("差异代谢峰/", files[fi]))
  prefix <- sub("\\.csv$", "", files[fi])

  cat("\n------ 处理/Processing:", prefix, "------\n")

  ## 合并注释和表达数据 / Merge annotation and expression
  colnames(diff_data)[1] <- "variable_id"
  apz <- object2@expression_data
  apz$variable_id <- rownames(apz)

  merged <- merge(app3, diff_data, by = "variable_id") %>%
    distinct(Compound.name, .keep_all = TRUE)
  merged <- merge(merged, apz, by = "variable_id")
  write.csv(merged, paste0("差异代谢物/代谢物_", prefix, ".csv"), row.names = FALSE)

  ## 提取ID / Extract IDs
  HMDB_ids <- normalize_hmdb(merged$HMDB.ID)
  KEGG_ids <- unique(merged$KEGG.ID[!is.na(merged$KEGG.ID) & merged$KEGG.ID != ""])
  sample_cols <- colnames(merged)[colnames(merged) %in% colnames(object2@expression_data)]

  cat("  差异代谢物/Diff metabolites:", nrow(merged),
      "| HMDB:", length(HMDB_ids), "| KEGG:", length(KEGG_ids), "\n")

  ## ==== WF1: SMPDB (tidymass) ====
  cat("  WF1: SMPDB...")
  if (has_tidymass && length(HMDB_ids) >= 3) {
    tryCatch({
      res1 <- enrich_hmdb(query_id = HMDB_ids, query_type = "compound",
                          id_type = "HMDB", pathway_database = hmdb_pathway,
                          only_primary_pathway = TRUE, p_cutoff = 0.99,
                          p_adjust_method = "BH")
      pw1 <- res1@result
      pw1 <- pw1[pw1$p_value < 0.05 & pw1$pathway_class == "Metabolic;primary_pathway", ]
      pw1 <- arrange(pw1, desc(mapped_number))

      ## 全部显著 + 过滤非特异性 / All significant + filtered
      pw1_filt <- filter_nonspecific(pw1, name_col = "pathway_name", size_col = "all_number")
      write.xlsx(pw1_filt$all, paste0("差异代谢物/smpdb_", prefix, ".xlsx"))
      if (nrow(pw1_filt$filtered) < nrow(pw1_filt$all)) {
        write.xlsx(pw1_filt$filtered, paste0("差异代谢物/smpdb_", prefix, "_filtered.xlsx"))
      }

      ## 绘图用过滤后数据 / Plot uses filtered data
      pw1_plot_data <- pw1_filt$filtered
      if (nrow(pw1_plot_data) > 0) {
        pw1_plot_data$neg_log_p <- -log10(pw1_plot_data$p_value)
        pw_plot <- prep_pathway_plot(pw1_plot_data)
        pw_plot$pathway_name <- factor(pw_plot$pathway_name, levels = rev(pw_plot$pathway_name))
        y_text_size <- if (SUBFIG_MODE) 9 else 8

        p_wf1 <- ggplot(pw_plot, aes(x = mapped_number, y = pathway_name)) +
          geom_point(aes(size = neg_log_p, color = mapped_number)) +
          scale_color_gradientn(colours = pathway_gradient) +
          labs(title = "SMPDB Pathway Enrichment (WF1-ORA)", x = "Mapped compounds") +
          theme_nature(base_size = 8) +
          theme(aspect.ratio = NULL, axis.title.y = element_blank(),
                axis.text.y = element_text(size = y_text_size)) +
          scale_size(range = c(3, 9))

        save_nature_plot(p_wf1, paste0("差异代谢物/smpdb_", prefix),
                         width = PATHWAY_FIG_W, height = PATHWAY_FIG_H)
      }
      cat(" 完成/done (", nrow(pw1_filt$all), "全部/all,",
          nrow(pw1_filt$filtered), "过滤后/filtered)\n")
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat(" 跳过/skipped\n")
  }

  ## ==== WF2: MSEA (MetaboAnalystR) ====
  cat("  WF2: MSEA...")
  if (has_metaboanalyst && length(HMDB_ids) >= 3) {
    tryCatch({
      mSet <- InitDataObjects("conc", "msetora", FALSE, default.dpi = 72)
      mSet <- Setup.MapData(mSet, HMDB_ids)
      mSet <- CrossReferencing(mSet, "hmdb")
      mSet <- CreateMappingResultTable(mSet)
      mSet <- SetMetabolomeFilter(mSet, FALSE)
      mSet <- SetCurrentMsetLib(mSet, "smpdb_pathway", 0)
      mSet <- CalculateHyperScore(mSet)

      if (!is.null(mSet$analSet$ora.mat)) {
        msea_res <- as.data.frame(mSet$analSet$ora.mat)
        msea_res$pathway <- rownames(msea_res)
        msea_res <- msea_res[order(msea_res[, "Raw p"]), ]

        ## 全部 + 过滤 / All + filtered
        total_col <- if ("Total" %in% colnames(msea_res)) "Total" else "total"
        msea_filt <- filter_nonspecific(msea_res, name_col = "pathway",
                                         size_col = if (total_col %in% colnames(msea_res)) total_col else NULL)
        write.xlsx(msea_filt$all, paste0("差异代谢物/msea_", prefix, ".xlsx"))
        if (nrow(msea_filt$filtered) < nrow(msea_filt$all)) {
          write.xlsx(msea_filt$filtered, paste0("差异代谢物/msea_", prefix, "_filtered.xlsx"))
        }

        msea_sig <- msea_filt$filtered[msea_filt$filtered[, "Raw p"] < 0.05, ]
        if (nrow(msea_sig) > 0) {
          msea_sig$neg_log_p <- -log10(msea_sig[, "Raw p"])
          pw_plot <- prep_pathway_plot(msea_sig)
          pw_plot$pathway <- factor(pw_plot$pathway, levels = rev(pw_plot$pathway))
          y_text_size <- if (SUBFIG_MODE) 9 else 8

          hits_col <- if ("hits" %in% colnames(pw_plot)) "hits" else "Hits"
          expected_col <- if ("expected" %in% colnames(pw_plot)) "expected" else "Expected"

          p_wf2 <- ggplot(pw_plot, aes(x = .data[[hits_col]], y = pathway)) +
            geom_point(aes(size = neg_log_p, color = .data[[expected_col]])) +
            scale_color_gradientn(colours = pathway_gradient) +
            labs(title = "MSEA Enrichment (WF2-ORA)", x = "Hits") +
            theme_nature(base_size = 8) +
            theme(aspect.ratio = NULL, axis.title.y = element_blank(),
                  axis.text.y = element_text(size = y_text_size)) +
            scale_size(range = c(3, 9))

          save_nature_plot(p_wf2, paste0("差异代谢物/msea_", prefix),
                           width = PATHWAY_FIG_W, height = PATHWAY_FIG_H)
        }
        cat(" 完成/done (", nrow(msea_filt$all), "全部/all,",
            nrow(msea_filt$filtered), "过滤后/filtered)\n")
      }
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat(" 跳过/skipped\n")
  }

  ## ==== WF3: KEGG Pathway ORA (KEGGREST + Fisher's exact test) ====
  ## 直接使用KEGGREST API获取通路数据，超几何检验做富集
  ## Uses KEGGREST API for pathway data + hypergeometric test for enrichment
  cat("  WF3: KEGG Pathway...")
  if (length(KEGG_ids) >= 3 && requireNamespace("KEGGREST", quietly = TRUE)) {
    tryCatch({
      library(KEGGREST)
      old_timeout <- getOption("timeout")
      options(timeout = 120)

      org_pathways <- keggList("pathway", ORGANISM)
      pw_nums <- sub(paste0("^", ORGANISM), "", names(org_pathways))
      pw_names <- sub(" - .*$", "", as.character(org_pathways))

      cpd_pw_link <- keggLink("pathway", "compound")
      cpd_link_ids <- sub("cpd:", "", names(cpd_pw_link))
      map_link_ids <- sub("path:map", "", as.character(cpd_pw_link))

      pw_cpd_sets <- list()
      all_kegg_cpds <- character()
      for (i in seq_along(pw_nums)) {
        matched_cpds <- cpd_link_ids[map_link_ids == pw_nums[i]]
        if (length(matched_cpds) >= 2) {
          pw_cpd_sets[[pw_names[i]]] <- matched_cpds
          all_kegg_cpds <- union(all_kegg_cpds, matched_cpds)
        }
      }
      options(timeout = old_timeout)

      N <- length(all_kegg_cpds)
      n <- length(intersect(KEGG_ids, all_kegg_cpds))

      kegg_results <- data.frame(
        pathway = character(), Total = integer(), Expected = numeric(),
        Hits = integer(), Raw_p = numeric(), stringsAsFactors = FALSE
      )

      for (pw_name in names(pw_cpd_sets)) {
        pw_cpds <- pw_cpd_sets[[pw_name]]
        K <- length(pw_cpds)
        hits <- intersect(KEGG_ids, pw_cpds)
        k <- length(hits)
        if (k >= 1) {
          expected <- K * n / N
          p_val <- phyper(k - 1, K, N - K, n, lower.tail = FALSE)
          kegg_results <- rbind(kegg_results, data.frame(
            pathway = pw_name, Total = K, Expected = round(expected, 2),
            Hits = k, Raw_p = p_val, stringsAsFactors = FALSE
          ))
        }
      }

      kegg_results <- kegg_results[order(kegg_results$Raw_p), ]
      kegg_results$FDR <- p.adjust(kegg_results$Raw_p, method = "BH")

      ## 全部 + 过滤 / All + filtered
      kegg_filt <- filter_nonspecific(kegg_results, name_col = "pathway", size_col = "Total")
      write.xlsx(kegg_filt$all, paste0("差异代谢物/kegg_", prefix, ".xlsx"))
      if (nrow(kegg_filt$filtered) < nrow(kegg_filt$all)) {
        write.xlsx(kegg_filt$filtered, paste0("差异代谢物/kegg_", prefix, "_filtered.xlsx"))
      }

      kegg_plot_data <- kegg_filt$filtered
      kegg_plot_data$neg_log_p <- -log10(kegg_plot_data$Raw_p)
      kegg_plot <- prep_pathway_plot(kegg_plot_data)
      label_size <- if (SUBFIG_MODE) 3.2 else 2.5

      if (nrow(kegg_plot) > 0) {
        p_mv <- ggplot(kegg_plot, aes(x = Hits, y = neg_log_p)) +
          geom_point(aes(size = Total, fill = neg_log_p),
                     shape = 21, color = "black", stroke = 0.3, alpha = 0.85) +
          scale_fill_gradientn(colours = pathway_gradient) +
          scale_size(range = c(2, 10)) +
          geom_hline(yintercept = -log10(0.05), lty = 2, color = "grey50", linewidth = 0.3) +
          ggrepel::geom_text_repel(
            data = kegg_plot[kegg_plot$Raw_p < 0.1 | kegg_plot$Hits >= 3, ],
            aes(label = pathway), size = label_size, max.overlaps = 15,
            segment.color = "grey60", segment.size = 0.3
          ) +
          labs(x = "Hits", y = expression("-log"[10]*"(p-value)"),
               title = paste0("KEGG Pathway Enrichment (", ORGANISM, ")"),
               size = "Pathway Size", fill = expression("-log"[10]*"(p)")) +
          theme_nature(base_size = 8)

        save_nature_plot(p_mv, paste0("差异代谢物/kegg_metabolome_view_", prefix),
                         width = PATHWAY_FIG_W, height = PATHWAY_FIG_H + 0.5)
      }
      cat(" 完成/done (", nrow(kegg_filt$all), "全部/all,",
          nrow(kegg_filt$filtered), "过滤后/filtered)\n")
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat(" 跳过/skipped\n")
  }

  ## ==== WF4: QEA (globaltest) ====
  ## 使用globaltest直接做定量富集分析，绕过MetaboAnalystR的Normalization兼容性问题
  ## Direct globaltest QEA — bypasses MetaboAnalystR 4.x Normalization bugs
  cat("  WF4: QEA...")
  if (nrow(merged) >= 5 && requireNamespace("globaltest", quietly = TRUE)) {
    tryCatch({
      library(globaltest)

      ## 构建表达矩阵 / Build expression matrix (samples x metabolites)
      qea_sub <- merged[!is.na(merged$Compound.name) & merged$Compound.name != "", ]
      qea_sub <- distinct(qea_sub, Compound.name, .keep_all = TRUE)
      qea_mat <- as.matrix(qea_sub[, sample_cols])
      rownames(qea_mat) <- qea_sub$Compound.name
      qea_expr <- t(log2(qea_mat + 1))
      grp <- factor(gsub("[0-9]", "", rownames(qea_expr)))

      ## 获取SMPDB通路库 / Get SMPDB pathway library
      pw_lib <- NULL
      if (has_metaboanalyst) {
        mSet_tmp <- InitDataObjects("conc", "msetora", FALSE, default.dpi = 72)
        mSet_tmp <- Setup.MapData(mSet_tmp, normalize_hmdb(merged$HMDB.ID[!is.na(merged$HMDB.ID)]))
        mSet_tmp <- CrossReferencing(mSet_tmp, "hmdb")
        mSet_tmp <- CreateMappingResultTable(mSet_tmp)
        mSet_tmp <- SetMetabolomeFilter(mSet_tmp, FALSE)
        mSet_tmp <- SetCurrentMsetLib(mSet_tmp, "smpdb_pathway", 0)
        if (file.exists("current.msetlib.qs")) pw_lib <- qs::qread("current.msetlib.qs")
      }

      ## 通路-代谢物映射 / Pathway-metabolite mapping
      hmdb_to_name <- setNames(qea_sub$Compound.name, normalize_hmdb(qea_sub$HMDB.ID))

      pw_sets <- list()
      if (!is.null(pw_lib)) {
        for (i in seq_len(nrow(pw_lib))) {
          pw_name <- pw_lib$name[i]
          pw_members <- if (is.list(pw_lib$member)) pw_lib$member[[i]] else unlist(strsplit(as.character(pw_lib$member[i]), "; "))
          mapped <- intersect(pw_members, colnames(qea_expr))
          hmdb_mapped <- hmdb_to_name[pw_members[pw_members %in% names(hmdb_to_name)]]
          all_mapped <- unique(c(mapped, hmdb_mapped[hmdb_mapped %in% colnames(qea_expr)]))
          if (length(all_mapped) >= 2) pw_sets[[pw_name]] <- all_mapped
        }
      }

      ## Fallback: 直接名称匹配 / Direct name matching
      if (length(pw_sets) == 0 && !is.null(pw_lib)) {
        for (i in seq_len(nrow(pw_lib))) {
          pw_name <- pw_lib$name[i]
          pw_members <- if (is.list(pw_lib$member)) pw_lib$member[[i]] else unlist(strsplit(as.character(pw_lib$member[i]), "; "))
          mapped <- intersect(pw_members, colnames(qea_expr))
          if (length(mapped) >= 2) pw_sets[[pw_name]] <- mapped
        }
      }

      if (length(pw_sets) >= 1) {
        qea_results <- data.frame(pathway = character(), p_value = numeric(),
                                   statistic = numeric(), hits = integer(),
                                   stringsAsFactors = FALSE)
        for (pw_name in names(pw_sets)) {
          pw_cols <- pw_sets[[pw_name]]
          pw_idx <- which(colnames(qea_expr) %in% pw_cols)
          gt_res <- gt(grp, qea_expr[, pw_idx, drop = FALSE])
          qea_results <- rbind(qea_results, data.frame(
            pathway = pw_name, p_value = p.value(gt_res),
            statistic = gt_res@result[1, "Statistic"],
            hits = length(pw_idx)
          ))
        }
        qea_results <- qea_results[order(qea_results$p_value), ]
        qea_results$FDR <- p.adjust(qea_results$p_value, method = "BH")

        ## 全部 + 过滤 / All + filtered
        qea_filt <- filter_nonspecific(qea_results, name_col = "pathway")
        write.xlsx(qea_filt$all, paste0("差异代谢物/qea_", prefix, ".xlsx"))
        if (nrow(qea_filt$filtered) < nrow(qea_filt$all)) {
          write.xlsx(qea_filt$filtered, paste0("差异代谢物/qea_", prefix, "_filtered.xlsx"))
        }

        qea_sig <- qea_filt$filtered[qea_filt$filtered$p_value < 0.05, ]
        if (nrow(qea_sig) > 0) {
          qea_sig$neg_log_p <- -log10(qea_sig$p_value)
          pw_plot <- prep_pathway_plot(qea_sig)
          pw_plot$pathway <- factor(pw_plot$pathway, levels = rev(pw_plot$pathway))
          y_text_size <- if (SUBFIG_MODE) 9 else 8

          p_wf4 <- ggplot(pw_plot, aes(x = hits, y = pathway)) +
            geom_point(aes(size = neg_log_p, color = statistic)) +
            scale_color_gradientn(colours = pathway_gradient) +
            labs(title = "QEA Enrichment (WF4-GlobalTest)", x = "Hits") +
            theme_nature(base_size = 8) +
            theme(aspect.ratio = NULL, axis.title.y = element_blank(),
                  axis.text.y = element_text(size = y_text_size)) +
            scale_size(range = c(3, 9))

          save_nature_plot(p_wf4, paste0("差异代谢物/qea_", prefix),
                           width = PATHWAY_FIG_W, height = PATHWAY_FIG_H)
        }
        cat(" 完成/done (", nrow(qea_filt$all), "全部/all,",
            nrow(qea_filt$filtered), "过滤后/filtered)\n")
      } else {
        cat(" 无足够通路映射/not enough pathway mappings\n")
      }
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat(" 跳过/skipped\n")
  }

  ## ==== 热图 / Heatmap ====
  cat("  Heatmap...")
  tryCatch({
    heat_data <- merged[, c("Compound.name", sample_cols)]
    heat_data <- distinct(heat_data, Compound.name, .keep_all = TRUE)
    rownames(heat_data) <- heat_data$Compound.name
    heat_data <- heat_data[, -1, drop = FALSE]
    heat_data <- as.data.frame(lapply(heat_data, as.numeric))
    rownames(heat_data) <- merged %>% distinct(Compound.name, .keep_all = TRUE) %>% pull(Compound.name)

    col_anno <- data.frame(Group = group, row.names = colnames(heat_data))
    anno_colors <- list(Group = setNames(nature_colors[c(4, 1)], c(CONTROL_GROUP, MODEL_GROUP)))

    if (nrow(heat_data) > 1 && ncol(heat_data) > 1) {
      fig_height <- max(9, nrow(heat_data) * 0.15 + 2)

      p_heat <- pheatmap(heat_data, cluster_cols = TRUE, cluster_rows = TRUE,
                         scale = "row", show_colnames = TRUE,
                         fontsize = 7, fontsize_row = 6, fontsize_col = 7,
                         color = heatmap_colors, border_color = NA,
                         annotation_col = col_anno, annotation_colors = anno_colors,
                         cellwidth = 16, cellheight = 10, silent = TRUE)

      pdf(paste0("差异代谢物/heatmap_", prefix, ".pdf"), width = 7, height = fig_height)
      print(p_heat)
      dev.off()

      tiff(paste0("差异代谢物/heatmap_", prefix, ".tiff"),
           width = 7, height = fig_height, units = "in", res = 300, compression = "lzw")
      print(p_heat)
      dev.off()
      cat(" 完成/done\n")
    } else {
      cat(" 跳过(数据不足)/skipped\n")
    }
  }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))

  ## ==== 汇总 / Summary ====
  summary_df <- data.frame(
    Parameter = c("Diff_metabolites", "HMDB_IDs", "KEGG_IDs",
                  "logFC_base", "logFC_cutoff", "Significance",
                  "Organism", "Polarity"),
    Value = c(nrow(merged), length(HMDB_ids), length(KEGG_ids),
              "log10", LOGFC_CUTOFF, paste0("adj.P.Val < ", ALPHA),
              ORGANISM, POLARITY)
  )
  write.xlsx(summary_df, paste0("差异代谢物/summary_", prefix, ".xlsx"))
}


## ========================= 9. Boxplot / Boxplot =========================
cat("\n========== Step 6: 箱线图 / Boxplots ==========\n")
dir.create("Boxplot", showWarnings = FALSE)

expre <- object2@expression_data
expre$variable_id <- rownames(expre)
app3_expr <- left_join(app3, expre, by = "variable_id")

cn_col <- which(colnames(app3_expr) == "Compound.name")
expr_start <- which(colnames(app3_expr) %in% colnames(object2@expression_data))
app3_box <- app3_expr[, c(cn_col[1], expr_start)]
app3_box <- app3_box[!is.na(app3_box$Compound.name), ]
box_list <- split(app3_box, app3_box$Compound.name)

box_count <- 0
for (nm in names(box_list)) {
  tryCatch({
    bx <- box_list[[nm]]
    bx <- bx[1, ]
    vals <- as.numeric(bx[, -1])
    grps <- gsub("[0-9]", "", colnames(bx)[-1])

    plot_df <- data.frame(value = vals, group = grps)
    grp_levels <- unique(grps)
    if (CONTROL_GROUP %in% grp_levels) {
      grp_levels <- c(CONTROL_GROUP, setdiff(grp_levels, CONTROL_GROUP))
    }
    plot_df$group <- factor(plot_df$group, levels = grp_levels)

    p_box <- ggplot(plot_df, aes(x = group, y = value, fill = group)) +
      geom_boxplot(alpha = 0.8, outlier.shape = NA, width = 0.6,
                   color = "black", linewidth = 0.3) +
      geom_jitter(width = 0.15, size = 1.5, shape = 21,
                  color = "black", stroke = 0.3, alpha = 0.8,
                  aes(fill = group)) +
      scale_fill_manual(values = nature_colors) +
      stat_compare_means(method = "t.test", ref.group = grp_levels[1],
                         aes(label = after_stat(p.signif)), size = 3.5) +
      labs(title = nm, y = "Intensity", x = "") +
      theme_nature(base_size = 8) +
      theme(legend.position = "none",
            axis.text.x = element_text(angle = 30, hjust = 1))

    save_nature_plot(p_box, paste0("Boxplot/", gsub("[^A-Za-z0-9_-]", "_", nm)),
                     width = 4, height = 4)
    box_count <- box_count + 1
  }, error = function(e) {})
}
cat("  箱线图完成 / Boxplots done:", box_count, "个\n")


## ========================= 10. 完成 / Done =========================
cat("\n\n")
cat("##############################################################\n")
cat("##  MetaboFlow v1.0 分析完成 / Analysis Complete             ##\n")
cat("##############################################################\n")
cat("  输出目录 / Output directories:\n")
cat("    差异代谢峰/   - 差异峰CSV + 火山图(PDF/TIFF)\n")
cat("    差异代谢物/   - 四工作流通路分析 + 热图\n")
cat("      smpdb_*     - WF1: SMPDB通路富集(ORA)\n")
cat("      msea_*      - WF2: MSEA代谢物集富集(ORA)\n")
cat("      kegg_*      - WF3: KEGG通路富集(ORA)\n")
cat("      qea_*       - WF4: 定量富集分析(QEA)\n")
cat("      heatmap_*   - 差异代谢物热图\n")
cat("      summary_*   - 参数汇总\n")
cat("    Boxplot/       - 单代谢物箱线图\n")
cat("##############################################################\n")

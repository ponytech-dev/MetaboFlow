##############################################################################
##  MetaboFlow v1.0 — 非靶向代谢组学四工作流集成分析系统
##  MetaboFlow v1.0 — Untargeted Metabolomics Quad-Workflow Integrated Pipeline
##
##  工作流 / Workflows:
##    1. tidymass enrich_hmdb  → SMPDB通路富集 / SMPDB Pathway Enrichment (ORA)
##    2. MetaboAnalystR MSEA   → 代谢物集富集分析 / Metabolite Set Enrichment (ORA)
##    3. MetaboAnalystR PathwayAnalysis → KEGG拓扑通路分析 / KEGG Topology Analysis (ORA)
##    4. MetaboAnalystR QEA    → 定量富集分析 / Quantitative Enrichment Analysis (QEA)
##
##  所有输出图表按 Nature 论文级别标准渲染：
##  All figures rendered to Nature publication standards:
##    - ggsci NPG/Lancet 配色 / color palettes
##    - PDF矢量输出 + 300 DPI TIFF备份 / vector PDF + 300 DPI TIFF
##    - 7×7英寸单栏 或 14×7英寸双栏 / single-column or double-column
##    - Arial字体, 7-9pt正文 / Arial font, 7-9pt body text
##############################################################################

## ========================= 0. 依赖安装 / Dependency Installation ========================= 
## 此段代码自动检测并安装所有必需包
## This section auto-detects and installs all required packages

cat("========== MetaboFlow v1.0 启动 / Initializing ==========\n")

## --- 0.1 基础包管理器 / Base package manager ---
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

## --- 0.2 CRAN包 / CRAN packages ---
cran_pkgs <- c("tidyverse", "openxlsx", "ggrepel", "pheatmap", "ggpubr",
               "ggsci", "patchwork", "devtools", "remotes", "Cairo")
for (pkg in cran_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  安装/Installing ", pkg, "...\n"))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

## --- 0.3 Bioconductor包 / Bioconductor packages ---
bioc_pkgs <- c("Biobase", "limma")
for (pkg in bioc_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  安装/Installing ", pkg, " (Bioconductor)...\n"))
    BiocManager::install(pkg, update = FALSE, ask = FALSE)
  }
}

## --- 0.4 tidymass / tidymass suite ---
if (!requireNamespace("tidymass", quietly = TRUE)) {
  cat("  安装tidymass（可能需要几分钟）/ Installing tidymass (may take minutes)...\n")
  remotes::install_gitlab("tidymass/tidymass", dependencies = TRUE)
}

## --- 0.5 MetaboAnalystR / MetaboAnalystR ---
## MetaboAnalystR 安装较复杂，需要多个系统依赖
## MetaboAnalystR installation is complex, requires system dependencies
if (!requireNamespace("MetaboAnalystR", quietly = TRUE)) {
  cat("  安装MetaboAnalystR... / Installing MetaboAnalystR...\n")
  cat("  注意：首次安装可能需要10-20分钟 / Note: first install may take 10-20 min\n")
  
  ## MetaboAnalystR依赖 / dependencies
  metabo_deps <- c("Rserve", "RColorBrewer", "xtable", "fitdistrplus",
                   "som", "ROCR", "RJSONIO", "gplots", "e1071", "caTools",
                   "igraph", "randomForest", "caret", "pls", "lattice")
  for (pkg in metabo_deps) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      tryCatch(
        install.packages(pkg, repos = "https://cloud.r-project.org"),
        error = function(e) cat(paste0("    警告/Warning: ", pkg, " 安装失败/failed\n"))
      )
    }
  }
  
  bioc_deps <- c("impute", "pcaMethods", "globaltest", "GlobalAncova", "Rgraphviz",
                 "preprocessCore", "genefilter", "SSPA", "sva", "limma",
                 "KEGGgraph", "BiocParallel", "MSnbase", "multtest", "RBGL",
                 "edgeR", "fgsea", "MAIT")
  for (pkg in bioc_deps) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      tryCatch(
        BiocManager::install(pkg, update = FALSE, ask = FALSE),
        error = function(e) cat(paste0("    警告/Warning: ", pkg, " 安装失败/failed\n"))
      )
    }
  }
  
  tryCatch({
    devtools::install_github("xia-lab/MetaboAnalystR", build = TRUE,
                             build_vignettes = FALSE, dependencies = FALSE)
    cat("  MetaboAnalystR 安装成功 / installed successfully\n")
  }, error = function(e) {
    cat("  MetaboAnalystR 安装失败 / installation failed\n")
    cat("  错误/Error: ", conditionMessage(e), "\n")
    cat("  工作流2和3将被跳过 / Workflows 2 & 3 will be skipped\n")
  })
}

## --- 0.6 加载所有包 / Load all packages ---
suppressPackageStartupMessages({
  library(Biobase)
  library(tidymass)
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

## MetaboAnalystR 可选加载 / optional load
has_metaboanalyst <- requireNamespace("MetaboAnalystR", quietly = TRUE)
if (has_metaboanalyst) {
  library(MetaboAnalystR)
  cat("  MetaboAnalystR 已加载 / loaded\n")
} else {
  cat("  MetaboAnalystR 未安装，工作流2&3跳过 / not installed, WF2&3 skipped\n")
}

if (!methods::isClass("NAnnotatedDataFrame")) {
  methods::setClass("NAnnotatedDataFrame", contains = "AnnotatedDataFrame")
}

cat("========== 所有依赖就绪 / All dependencies ready ==========\n\n")


## ========================= 1. 用户参数区 / User Parameters ========================= 
## ▼▼▼ 以下参数需要用户根据实验设计修改 ▼▼▼
## ▼▼▼ Modify parameters below according to your experiment ▼▼▼

WORK_DIR       <- "path/to/your/data"   # 工作路径 / working directory (use forward slashes on all OS)
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

## 数据库路径（根据本地安装调整）/ Database paths (adjust to local installation)
## 使用正斜杠或file.path()以兼容所有操作系统 / Use forward slashes or file.path() for cross-platform
DB_DIR <- "path/to/your/inhouse_database"

## ▲▲▲ 参数区结束 ▲▲▲
## ▲▲▲ End of user parameters ▲▲▲


## ========================= 2. Nature级别绘图主题 / Nature-Quality Plot Theme ========================= 
## 参考Nature Methods投稿指南：Arial字体, 7-9pt, 单栏89mm(3.5in), 双栏183mm(7.2in)
## Reference: Nature Methods submission guidelines

## --- 2.1 统一主题 / Unified theme ---
theme_nature <- function(base_size = 8) {
  theme_bw(base_size = base_size) %+replace%
    theme(
      ## 字体 / Fonts
      text = element_text(family = "Arial", color = "black"),
      axis.title = element_text(size = base_size + 1, face = "bold"),
      axis.text = element_text(size = base_size, color = "black"),
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0),
      legend.title = element_text(size = base_size, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      strip.text = element_text(size = base_size, face = "bold"),
      ## 边框和网格 / Border and grid
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.6),
      axis.ticks = element_line(color = "black", linewidth = 0.4),
      ## 间距 / Spacing
      plot.margin = margin(8, 8, 8, 8, "pt"),
      legend.key.size = unit(0.35, "cm"),
      ## 纵横比 / Aspect ratio
      aspect.ratio = 1
    )
}

## --- 2.2 Nature配色方案 / Nature color palettes ---
## NPG配色(Nature Publishing Group) / NPG palette
nature_colors <- c(
  "#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F",
  "#8491B4", "#91D1C2", "#DC0000", "#7E6148", "#B09C85"
)

## 通路富集气泡图配色 / Pathway enrichment bubble colors
pathway_gradient <- c("#FDE725", "#35B779", "#31688E", "#440154")

## 火山图配色 / Volcano plot colors
volcano_colors <- c(Down = "#3C5488", Not = "#D3D3D3", Up = "#E64B35")

## 热图配色 / Heatmap colors
heatmap_colors <- colorRampPalette(c("#3C5488", "white", "#E64B35"))(100)

## --- 2.3 高质量保存函数 / High-quality save function ---
## 同时输出PDF(矢量)和TIFF(300DPI光栅)
## Saves both PDF (vector) and TIFF (300 DPI raster)
save_nature_plot <- function(plot_obj, filename, width = 7, height = 7) {
  ## PDF矢量图 / Vector PDF
  ggsave(paste0(filename, ".pdf"), plot = plot_obj,
         width = width, height = height, units = "in", device = cairo_pdf)
  ## TIFF光栅图(投稿用) / Raster TIFF (for submission)
  ggsave(paste0(filename, ".tiff"), plot = plot_obj,
         width = width, height = height, units = "in", dpi = 300,
         compression = "lzw")
}


## ========================= 2.5 HMDB ID格式统一 / HMDB ID Normalization =========================
## 旧版HMDB00132(11位) → 新版HMDB0000132(13位)
## Old format HMDB00132 (11 chars) → New format HMDB0000132 (13 chars)
## 在rm()之前定义，确保函数在环境清理时已存在
## Defined before rm() to ensure the function exists during env cleanup
normalize_hmdb <- function(ids) {
  ids <- ids[!is.na(ids) & ids != ""]
  ids <- ifelse(
    nchar(ids) == 11 & grepl("^HMDB\\d{5}$", ids),
    paste0("HMDB00", substring(ids, 5)),
    ids
  )
  unique(ids)
}


## ========================= 3. 数据处理 / Data Processing =========================

rm(list = setdiff(ls(), c("WORK_DIR","POLARITY","LOGFC_CUTOFF","ALPHA","ORGANISM",
                           "MS1_PPM","PEAK_WIDTH","SN_THRESH","NOISE_LEVEL",
                           "MIN_FRACTION","N_THREADS","INTENSITY_FLOOR","NORM_METHOD",
                           "CONTROL_GROUP","MODEL_GROUP",
                           "DB_DIR","theme_nature","nature_colors","pathway_gradient",
                           "volcano_colors","heatmap_colors","save_nature_plot",
                           "has_metaboanalyst","normalize_hmdb")))

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
## 按列名提取mz和rt，而非按位置索引 / Select by column name, not position index
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
## 使用tidymass API过滤，保持对象内部一致性 / Use tidymass API to maintain object consistency
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

## Nature级别PCA图 / Nature-quality PCA plot
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

## --- 核心函数：limma差异分析 / Core function: limma differential analysis ---
run_limma <- function(data_ctl, data_treat, feature_names) {
  ## 合并数据 / Merge data
  ana <- cbind(data_ctl, data_treat)
  rownames(ana) <- feature_names   # 不插入id列 / No id column
  
  ## 设计矩阵 / Design matrix
  type_vec <- c(rep("CTL", ncol(data_ctl)), rep("TREAT", ncol(data_treat)))
  design <- model.matrix(~ 0 + factor(type_vec))
  colnames(design) <- c("CTL", "TREAT")
  
  ## limma拟合 / limma fit
  fit <- lmFit(as.data.frame(ana), design = design)
  fit2 <- contrasts.fit(fit, makeContrasts(TREAT - CTL, levels = design))
  fit2 <- eBayes(fit2)
  Diff <- topTable(fit2, adjust = "fdr", number = nrow(ana))
  
  ## 使用adj.P.Val筛选 / Filter by adj.P.Val
  sig <- Diff[abs(Diff$logFC) >= LOGFC_CUTOFF & Diff$adj.P.Val < ALPHA, ]
  
  list(all = Diff, sig = sig)
}

## --- 核心函数：Nature级别火山图 / Core function: Nature-quality volcano plot ---
plot_volcano_nature <- function(Diff, title_text, filename) {
  Diff$Significance <- ifelse(
    Diff$adj.P.Val < ALPHA & abs(Diff$logFC) > LOGFC_CUTOFF,
    ifelse(Diff$logFC > 0, "Up", "Down"), "Not"
  )
  Diff$Significance <- factor(Diff$Significance, levels = c("Down", "Not", "Up"))
  
  n_up <- sum(Diff$Significance == "Up")
  n_down <- sum(Diff$Significance == "Down")
  
  p <- ggplot(Diff, aes(logFC, -log10(adj.P.Val))) +
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
         y = expression("-log"[10]*"(adj. P-value)"),
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

## Model组 vs Control / Model vs Control
if (any(con)) {
  res_model <- run_limma(log_PCA_data[, con], log_PCA_data[, model_grp],
                         rownames(object2@expression_data))
  write.csv(res_model$sig, "差异代谢峰/Model差异峰.csv", row.names = FALSE)
  plot_volcano_nature(res_model$all, "Model vs. Control",
                      "差异代谢峰/Model差异代谢峰")
  cat("  Model组: ", nrow(res_model$sig), "个差异代谢峰 / differential features\n")
}

## 其他组 vs Model / Other groups vs Model
other <- group != CONTROL_GROUP & group != MODEL_GROUP
if (any(other)) {
  CTL_ref <- log_PCA_data[, model_grp]
  for (grp in unique(group[other])) {
    treat <- log_PCA_data[, group == grp]
    res <- run_limma(CTL_ref, treat, rownames(object2@expression_data))
    write.csv(res$sig, paste0("差异代谢峰/", grp, "差异峰.csv"), row.names = FALSE)
    plot_volcano_nature(res$all, paste0(grp, " vs. Model"),
                        paste0("差异代谢峰/", grp, "差异代谢峰"))
    cat("  ", grp, "组:", nrow(res$sig), "个差异代谢峰\n")
  }
}


## ========================= 6. 代谢物注释 / Metabolite Annotation ========================= 
cat("\n========== Step 4: 代谢物注释 / Metabolite Annotation ==========\n")

## 加载数据库 / Load databases
load(file.path(DB_DIR, "inhouse_Metabolite.database"))
load(file.path(DB_DIR, "hmdb_ms2_merged.rda"))
load(file.path(DB_DIR, "massbank_ms2_merged.rda"))
load(file.path(DB_DIR, "mona_ms2_merged.rda"))
load(file.path(DB_DIR, "orbitrap_database0.0.3.rda"))

## Inhouse库(有RT) / Inhouse database (with RT)
object1 <- annotate_metabolites_mass_dataset(
  object = object2, ms1.match.ppm = MS1_PPM, rt.match.tol = 6000,
  polarity = POLARITY, database = inhouse_Metabolite.database)

## 公共库(无RT，rt.match.tol设大值) / Public DBs (no RT, large tolerance)
## 注意：文章中需标注MSI Level 2/3 / Note: mark as MSI Level 2/3 in paper
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


## ========================= 7. 三工作流集成 / Tri-Workflow Integration ========================= 
cat("\n========== Step 5: 三工作流通路分析 / Tri-Workflow Pathway Analysis ==========\n")
dir.create("差异代谢物", showWarnings = FALSE)

## --- Nature级别通路气泡图函数 / Nature-quality pathway bubble plot ---
plot_pathway_bubble <- function(pw_data, x_col, y_col, size_col, color_col,
                                title_text, filename, width = 7, height = 5) {
  if (nrow(pw_data) == 0) return(NULL)
  pw_plot <- if (nrow(pw_data) <= 12) pw_data else pw_data[1:12, ]
  pw_plot[[y_col]] <- factor(pw_plot[[y_col]], levels = rev(pw_plot[[y_col]]))
  
  p <- ggplot(pw_plot, aes_string(x = x_col, y = y_col)) +
    geom_point(aes_string(size = size_col, color = color_col)) +
    scale_color_gradientn(colours = pathway_gradient) +
    labs(title = title_text, x = x_col) +
    theme_nature(base_size = 8) +
    theme(aspect.ratio = NULL,
          axis.title.y = element_blank(),
          axis.text.y = element_text(size = 8)) +
    scale_size(range = c(3, 9))
  
  save_nature_plot(p, filename, width = width, height = height)
  return(p)
}

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
  
  cat("  差异代谢物/Diff metabolites:", nrow(merged),
      "| HMDB:", length(HMDB_ids), "| KEGG:", length(KEGG_ids), "\n")
  
  ## ==== 工作流1: SMPDB (tidymass) ====
  cat("  WF1: SMPDB...")
  tryCatch({
    res1 <- enrich_hmdb(query_id = HMDB_ids, query_type = "compound",
                        id_type = "HMDB", pathway_database = hmdb_pathway,
                        only_primary_pathway = TRUE, p_cutoff = 0.99,
                        p_adjust_method = "BH")
    pw1 <- res1@result
    pw1 <- pw1[pw1$p_value < 0.05 & pw1$pathway_class == "Metabolic;primary_pathway", ]
    pw1 <- arrange(pw1, desc(mapped_number))
    write.xlsx(pw1, paste0("差异代谢物/smpdb_", prefix, ".xlsx"))
    
    if (nrow(pw1) > 0) {
      pw1$neg_log_p <- -log10(pw1$p_value)
      plot_pathway_bubble(pw1, "mapped_number", "pathway_name", "neg_log_p", "mapped_number",
                          "SMPDB Pathway Enrichment", paste0("差异代谢物/smpdb_", prefix))
    }
    cat(" 完成/done (", nrow(pw1), "条通路/pathways)\n")
  }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  
  ## ==== 工作流2: MSEA (MetaboAnalystR) ====
  if (has_metaboanalyst && length(HMDB_ids) >= 3) {
    cat("  WF2: MSEA...")
    tryCatch({
      ## ORA工作流只需Setup.MapData，不需要Read.TextData / ORA only needs Setup.MapData
      mSet <- InitDataObjects("conc", "msetora", FALSE)
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
        write.xlsx(msea_res, paste0("差异代谢物/msea_", prefix, ".xlsx"))
        
        msea_sig <- msea_res[msea_res[, "Raw p"] < 0.05, ]
        if (nrow(msea_sig) > 0) {
          msea_sig$neg_log_p <- -log10(msea_sig[, "Raw p"])
          plot_pathway_bubble(msea_sig, "Hits", "pathway", "neg_log_p", "Expected",
                              "MSEA Enrichment", paste0("差异代谢物/msea_", prefix))
        }
        cat(" 完成/done (", nrow(msea_res), "行/rows)\n")
      }
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat("  WF2: 跳过/skipped\n")
  }
  
  ## ==== 工作流3: KEGG Pathway (MetaboAnalystR) ====
  if (has_metaboanalyst && length(KEGG_ids) >= 3) {
    cat("  WF3: KEGG Pathway...")
    tryCatch({
      ## ORA工作流只需Setup.MapData / ORA only needs Setup.MapData
      mSet2 <- InitDataObjects("conc", "pathora", FALSE)
      mSet2 <- Setup.MapData(mSet2, KEGG_ids)
      mSet2 <- CrossReferencing(mSet2, "kegg")
      mSet2 <- CreateMappingResultTable(mSet2)
      mSet2 <- SetKEGG.PathLib(mSet2, ORGANISM, "current")
      mSet2 <- CalculateOraScore(mSet2, "rbc", "fisher")
      
      if (!is.null(mSet2$analSet$ora.mat)) {
        kegg_res <- as.data.frame(mSet2$analSet$ora.mat)
        kegg_res$pathway <- rownames(kegg_res)
        kegg_res <- kegg_res[order(kegg_res[, "Raw p"]), ]
        write.xlsx(kegg_res, paste0("差异代谢物/kegg_", prefix, ".xlsx"))
        
        ## Metabolome View 散点图 / Metabolome View scatter plot
        kegg_res$neg_log_p <- -log10(kegg_res[, "Raw p"])
        
        p_mv <- ggplot(kegg_res, aes(x = Impact, y = neg_log_p)) +
          geom_point(aes(size = Hits, fill = neg_log_p),
                     shape = 21, color = "black", stroke = 0.3, alpha = 0.85) +
          scale_fill_gradientn(colours = pathway_gradient) +
          scale_size(range = c(2, 10)) +
          geom_hline(yintercept = -log10(0.05), lty = 2, color = "grey50", linewidth = 0.3) +
          ggrepel::geom_text_repel(
            data = kegg_res[kegg_res[, "Raw p"] < 0.1 | kegg_res$Impact > 0.1, ],
            aes(label = pathway), size = 2.5, max.overlaps = 12,
            segment.color = "grey60", segment.size = 0.3
          ) +
          labs(x = "Pathway Impact", y = expression("-log"[10]*"(p-value)"),
               title = paste0("Metabolome View (", ORGANISM, ")"),
               size = "Hits", fill = expression("-log"[10]*"(p)")) +
          theme_nature(base_size = 8)
        
        save_nature_plot(p_mv, paste0("差异代谢物/kegg_metabolome_view_", prefix),
                         width = 6, height = 5.5)
        
        cat(" 完成/done (", nrow(kegg_res), "条通路/pathways)\n")
      }
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat("  WF3: 跳过/skipped\n")
  }

  ## ==== 工作流4: QEA 定量富集分析 (MetaboAnalystR) ====
  ## 与ORA不同，QEA直接使用浓度/强度矩阵，不需要预先筛选差异代谢物
  ## Unlike ORA, QEA uses the full concentration matrix — no pre-screening needed
  ## 输入：已注释代谢物的浓度矩阵 + 分组标签
  ## Input: annotated metabolite concentration matrix + group labels
  if (has_metaboanalyst && nrow(merged) >= 5) {
    cat("  WF4: QEA...")
    tryCatch({
      ## 构建QEA输入矩阵 / Build QEA input matrix
      ## 格式：第1列=标签(Label)，后续列=代谢物名称，行=样本
      ## Format: col1=Label, remaining cols=compound names, rows=samples
      qea_expr_cols <- colnames(merged)[colnames(merged) %in% colnames(object2@expression_data)]
      qea_mat <- merged[, c("Compound.name", qea_expr_cols)]
      qea_mat <- distinct(qea_mat, Compound.name, .keep_all = TRUE)
      rownames(qea_mat) <- qea_mat$Compound.name
      qea_mat <- qea_mat[, -1, drop = FALSE]

      ## 转置：行=样本, 列=代谢物 / Transpose: rows=samples, cols=metabolites
      qea_t <- as.data.frame(t(qea_mat))
      qea_t$Label <- gsub("[0-9]", "", rownames(qea_t))
      qea_t <- qea_t[, c("Label", setdiff(colnames(qea_t), "Label"))]

      ## 写入临时CSV / Write temp CSV for Read.TextData
      qea_file <- tempfile(fileext = ".csv")
      write.csv(qea_t, qea_file, row.names = FALSE)

      mSet3 <- InitDataObjects("conc", "msetqea", FALSE)
      mSet3 <- Read.TextData(mSet3, qea_file, "rowu", "disc")
      mSet3 <- SanityCheckData(mSet3)
      mSet3 <- ReplaceMin(mSet3)
      mSet3 <- CrossReferencing(mSet3, "name")
      mSet3 <- CreateMappingResultTable(mSet3)
      mSet3 <- PreparePrenormData(mSet3)
      mSet3 <- Normalization(mSet3, "NULL", "LogNorm", "NULL", ratio = FALSE, ratioNum = 20)
      mSet3 <- SetMetabolomeFilter(mSet3, FALSE)
      mSet3 <- SetCurrentMsetLib(mSet3, "smpdb_pathway", 2)
      mSet3 <- CalculateGlobalTestScore(mSet3)

      if (!is.null(mSet3$analSet$qea.mat)) {
        qea_res <- as.data.frame(mSet3$analSet$qea.mat)
        qea_res$pathway <- rownames(qea_res)
        qea_res <- qea_res[order(qea_res[, "Raw p"]), ]
        write.xlsx(qea_res, paste0("差异代谢物/qea_", prefix, ".xlsx"))

        qea_sig <- qea_res[qea_res[, "Raw p"] < 0.05, ]
        if (nrow(qea_sig) > 0) {
          qea_sig$neg_log_p <- -log10(qea_sig[, "Raw p"])
          plot_pathway_bubble(qea_sig, "Hits", "pathway", "neg_log_p", "Expected",
                              "QEA Enrichment", paste0("差异代谢物/qea_", prefix))
        }
        cat(" 完成/done (", nrow(qea_res), "条通路/pathways)\n")
      } else {
        cat(" 无结果/no results\n")
      }
    }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))
  } else {
    cat("  WF4: 跳过/skipped\n")
  }

  ## ==== 热图 / Heatmap ====
  cat("  Heatmap...")
  tryCatch({
    ## 定位表达数据列 / Locate expression columns
    expr_cols <- colnames(merged)[colnames(merged) %in% colnames(object2@expression_data)]
    heat_data <- merged[, c("Compound.name", expr_cols)]
    heat_data <- distinct(heat_data, Compound.name, .keep_all = TRUE)
    rownames(heat_data) <- heat_data$Compound.name
    heat_data <- heat_data[, -1, drop = FALSE]
    
    if (nrow(heat_data) > 1 && ncol(heat_data) > 1) {
      ## Nature配色热图 / Nature-palette heatmap
      p_heat <- pheatmap(heat_data, cluster_cols = TRUE, cluster_rows = TRUE,
                         scale = "row", show_colnames = TRUE,
                         fontsize = 7, fontsize_row = 7, fontsize_col = 7,
                         color = heatmap_colors, border_color = NA,
                         cellwidth = 16, cellheight = 12, silent = TRUE)
      
      pdf(paste0("差异代谢物/heatmap_", prefix, ".pdf"), width = 7, height = 9)
      print(p_heat)
      dev.off()
      
      tiff(paste0("差异代谢物/heatmap_", prefix, ".tiff"),
           width = 7, height = 9, units = "in", res = 300, compression = "lzw")
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

## 检查Compound.name列位置 / Check Compound.name column position
cn_col <- which(colnames(app3_expr) == "Compound.name")
expr_start <- which(colnames(app3_expr) %in% colnames(object2@expression_data))
app3_box <- app3_expr[, c(cn_col[1], expr_start)]
app3_box <- app3_box[!is.na(app3_box$Compound.name), ]
box_list <- split(app3_box, app3_box$Compound.name)

for (nm in names(box_list)) {
  tryCatch({
    bx <- box_list[[nm]]
    bx <- bx[1, ]  # 取第一个注释 / take first annotation
    vals <- as.numeric(bx[, -1])
    grps <- gsub("[0-9]", "", colnames(bx)[-1])
    
    plot_df <- data.frame(value = vals, group = grps)
    grp_levels <- unique(grps)
    ## control排第一 / control first
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
  }, error = function(e) {})
}
cat("  箱线图完成 / Boxplots done\n")


## ========================= 10. 完成 / Done ========================= 
cat("\n\n")
cat("##############################################################\n")
cat("##  MetaboFlow v1.0 分析完成 / Analysis Complete             ##\n")
cat("##############################################################\n")
cat("  输出目录 / Output directories:\n")
cat("    差异代谢峰/   - 差异峰CSV + 火山图(PDF/TIFF)\n")
cat("    差异代谢物/   - 三工作流通路分析 + 热图\n")
cat("      smpdb_*     - WF1: SMPDB通路富集(ORA)\n")
cat("      msea_*      - WF2: MSEA代谢物集富集(ORA)\n")
cat("      kegg_*      - WF3: KEGG拓扑通路分析(ORA)\n")
cat("      qea_*       - WF4: 定量富集分析(QEA)\n")
cat("      heatmap_*   - 差异代谢物热图\n")
cat("      summary_*   - 参数汇总\n")
cat("    Boxplot/       - 单代谢物箱线图\n")
cat("##############################################################\n")

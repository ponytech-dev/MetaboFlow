##############################################################################
##  stats-worker/R/config.R
##  常量配置 / Constants and defaults for stats-worker
##
##  定义所有颜色方案、过滤关键词和图表默认参数。
##  Defines all color palettes, filter keywords, and plot default parameters.
##  No functions, no global side-effects — pure constant definitions.
##############################################################################

## ========================= 颜色方案 / Color Palettes =========================

## NPG 10色配色，用于分组散点/箱线图
## NPG 10-color palette for group scatter / boxplot
nature_colors <- c(
  "#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F",
  "#8491B4", "#91D1C2", "#DC0000", "#7E6148", "#B09C85"
)

## 通路富集图渐变色：从黄到深紫 / Pathway enrichment gradient: yellow → deep purple
pathway_gradient <- c("#FDE725", "#35B779", "#31688E", "#440154")

## 火山图三分类配色 / Volcano plot three-class colors
volcano_colors <- c(Down = "#3C5488", Not = "#D3D3D3", Up = "#E64B35")

## 热图色带：蓝-白-红 / Heatmap color ramp: blue-white-red
heatmap_colors <- colorRampPalette(c("#3C5488", "white", "#E64B35"))(100)


## ========================= 非特异性通路过滤 / Non-specific Pathway Filter =========================

## 过于宽泛的通路关键词黑名单——在几乎任何代谢组数据中都会显著（假阳性）
## Blacklist of over-broad pathway names — appear significant in virtually any dataset
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

## 通路代谢物数上限：超过此阈值视为非特异性
## Pathway member count ceiling: above this threshold → non-specific
NONSPECIFIC_SIZE_CUTOFF <- 150


## ========================= 图表默认参数 / Plot Default Parameters =========================

## 小子图模式默认关：开启时自动放大字体以适应论文小子图版式
## Sub-figure mode default off: enables auto font-enlargement for paper sub-figures
SUBFIG_MODE <- FALSE

## 通路图中最多展示的通路数（0 = 全部显著通路）
## Max pathways displayed in enrichment plots (0 = all significant)
TOP_N_PATHWAYS <- 0

## 通路图输出尺寸（英寸） / Pathway figure output dimensions (inches)
PATHWAY_FIG_W <- 7
PATHWAY_FIG_H <- 5

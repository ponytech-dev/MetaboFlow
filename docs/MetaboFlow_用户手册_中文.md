# MetaboFlow v1.0 用户手册

**非靶向代谢组学四工作流集成分析系统**

---

## 目录

1. [系统简介](#1-系统简介)
2. [四个工作流](#2-四个工作流)
3. [系统要求](#3-系统要求)
4. [安装与环境配置](#4-安装与环境配置)
5. [输入数据要求](#5-输入数据要求)
6. [参数设置](#6-参数设置)
7. [运行方式](#7-运行方式)
8. [输出文件说明](#8-输出文件说明)
9. [图表标准](#9-图表标准)
10. [常见问题与解决方案](#10-常见问题与解决方案)
11. [引用](#11-引用)

---

## 1. 系统简介

MetaboFlow 是一套基于 R 语言的非靶向 LC-MS 代谢组学全流程分析系统，集成了特征提取、归一化、差异分析、代谢物注释，以及**四个并行通路富集工作流**（3 个 ORA + 1 个 QEA）用于交叉验证。所有图表按 **Nature 论文投稿标准**渲染。

核心特色：

- **一次输入，四路输出** — 单次运行同时执行四种独立通路分析方法
- **全自动依赖管理** — 首次运行自动安装所有 CRAN、Bioconductor、tidymass、MetaboAnalystR 依赖包
- **优雅降级** — 若 tidymass 或 MetaboAnalystR 安装失败，可用工作流仍正常运行
- **Nature 级出图** — NPG 配色、Arial 字体、PDF 矢量 + 300 DPI TIFF 双格式输出
- **HMDB ID 自动标准化** — 自动将旧 7 位格式转换为新 11 位格式
- **智能 P 值选择** — 自动检测 FDR 校正 P 值可用性；样本量 ≤3 时回退使用原始 P 值
- **中英双语注释** — 所有代码注释中英文对照

---

## 2. 四个工作流

| 工作流 | 类型 | 引擎 | 数据库 | 特点 |
|--------|------|------|--------|------|
| **WF1**: SMPDB 通路富集 | ORA | tidymass `enrich_hmdb` | SMPDB/HMDB | 与 tidymass 无缝集成，HMDB ID 直接映射 |
| **WF2**: MSEA 代谢物集富集 | ORA | MetaboAnalystR | SMPDB 代谢物集 | 超几何检验，人工策划代谢物集 |
| **WF3**: KEGG 通路富集 | ORA | KEGGREST + Fisher 精确检验 | KEGG 物种特异通路 | 实时 KEGG 数据，超几何检验 |
| **WF4**: QEA 定量富集分析 | QEA | globaltest | SMPDB 通路 | 使用完整浓度矩阵，GlobalTest 统计 |

### 工作流说明

**WF1 — SMPDB 通路富集（tidymass）**
使用 tidymass 的 `enrich_hmdb()` 函数，基于 HMDB ID 对 SMPDB 数据库执行过表达分析（ORA）。优势是与 tidymass 上游处理流程完全兼容。

**WF2 — MSEA（MetaboAnalystR）**
使用 MetaboAnalystR 的代谢物集富集分析（MSEA），基于 SMPDB 策划的代谢物集执行超几何检验。

**WF3 — KEGG 通路富集（KEGGREST + Fisher）**
通过 KEGGREST 实时获取物种特异性 KEGG 通路信息，将差异代谢物的 KEGG ID 映射到对应通路，使用 Fisher 精确检验进行富集分析。支持所有 KEGG 收录的生物种（通过 ORGANISM 参数指定）。

**WF4 — 定量富集分析（globaltest）**
与前三个基于列表的 ORA 方法不同，WF4 使用完整的浓度/丰度矩阵，通过 globaltest 的 `gt()` 函数对每条通路执行全局检验，能更好地利用定量信息。

---

## 3. 系统要求

### 3.1 操作系统

| 操作系统 | 最低版本 |
|----------|----------|
| macOS | 12 (Monterey) 及以上 |
| Ubuntu | 20.04 及以上 |
| Debian | 11 及以上 |
| CentOS | 8 及以上 |
| Windows | 10/11 |

### 3.2 R 环境

| 组件 | 要求 | 说明 |
|------|------|------|
| **R** | **≥ 4.5.0**（必需） | tidymass 要求 R ≥ 4.5；推荐 R 4.5.3 |
| **RStudio** | ≥ 2024.04 | 推荐用于交互式使用，非必需 |
| **BiocManager** | ≥ 1.30.22 | MetaboFlow 会自动安装 |

> ⚠️ **重要**: R 版本 **必须 ≥ 4.5.0**。tidymass 的核心组件 masstools 严格要求 R ≥ 4.5，低版本 R 将无法安装 tidymass（WF1 不可用）。

### 3.3 硬件要求

| 资源 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 内存 (RAM) | 8 GB | 16 GB+（大数据集） |
| 磁盘空间 | 5 GB（R 包安装） | 10 GB+ |
| CPU | 4 核 | 8+ 核（并行色谱峰提取） |
| 网络 | 首次运行必需 | 包下载 + KEGG API 查询 |

### 3.4 R 包依赖列表

MetaboFlow 在首次运行时**自动检测并安装**所有依赖。完整依赖列表如下：

#### CRAN 包

| 包名 | 用途 |
|------|------|
| `tidyverse` | 数据处理与可视化基础框架 |
| `openxlsx` | Excel 文件读写 |
| `ggrepel` | 图表标签防重叠 |
| `pheatmap` | 聚类热图 |
| `ggpubr` | 统计可视化 |
| `ggsci` | Nature/Science 配色方案 |
| `patchwork` | 图表拼接 |
| `remotes` | GitHub/GitLab 包安装 |
| `Cairo` | 高质量图形设备 |
| `qs` | 快速序列化（MetaboAnalystR 依赖） |
| `survival` | 生存分析（MetaboAnalystR 依赖） |

#### Bioconductor 包

| 包名 | 用途 |
|------|------|
| `Biobase` | 生物信息学基础结构 |
| `limma` | 线性模型差异分析 |
| `KEGGREST` | KEGG API 客户端（WF3） |
| `globaltest` | 全局检验（WF4） |
| `xcms` | 色谱峰提取与对齐 |
| `MSnbase` | 质谱数据结构 |
| `BiocParallel` | 并行计算框架 |
| `impute` | 缺失值填补 |
| `pcaMethods` | PCA 分析 |
| `preprocessCore` | 数据预处理 |
| `genefilter` | 特征过滤 |
| `sva` | 批次效应校正 |
| `KEGGgraph` | KEGG 图结构 |
| `multtest` | 多重检验校正 |
| `RBGL` | 图算法 |
| `Rgraphviz` | 图可视化 |
| `edgeR` | 差异表达分析 |
| `fgsea` | 快速基因集富集分析 |

#### GitHub/GitLab 包

| 包名 | 来源 | 用途 |
|------|------|------|
| `tidymass` | GitLab: tidymass/tidymass | WF1 + 上游数据处理 |
| `MetaboAnalystR` | GitHub: xia-lab/MetaboAnalystR | WF2 + WF4 通路库 |

---

## 4. 安装与环境配置

### 方案一：conda 环境（推荐）

```bash
# 1. 创建 R 4.5.3 环境
conda create -n metaboflow -c conda-forge r-base=4.5.3

# 2. 激活环境
conda activate metaboflow

# 3. 运行 MetaboFlow（首次运行自动安装所有依赖包）
Rscript MetaboFlow_v1.r
```

> ⚠️ 首次运行需要 **20–40 分钟**下载安装所有 R 包。后续运行无需等待。

### 方案二：系统 R

1. 从 [CRAN](https://cran.r-project.org/) 下载安装 R ≥ 4.5.0
2. （可选）安装 RStudio
3. 打开 RStudio 或终端，运行 `Rscript MetaboFlow_v1.r`
4. 所有依赖包首次运行时自动安装

### 方案三：Docker（即将支持）

### 安装过程说明

MetaboFlow 的自动安装流程：

1. 检测 R 版本是否 ≥ 4.5.0
2. 安装/升级 BiocManager
3. 依次安装 CRAN 包、Bioconductor 包
4. 从 GitLab 安装 tidymass
5. 从 GitHub 安装 MetaboAnalystR
6. 若某个包安装失败，标记对应工作流不可用，继续安装其余包
7. 打印可用工作流摘要

---

## 5. 输入数据要求

### 5.1 文件格式

- 所有样本的 `.mzXML` 文件放在**同一目录**下
- 支持正离子模式和负离子模式（通过 `POLARITY` 参数指定）

### 5.2 文件命名规则

```
[组名][编号].mzXML
```

示例：
- `control1.mzXML`, `control2.mzXML`, `control3.mzXML`
- `DrugA1.mzXML`, `DrugA2.mzXML`, `DrugA3.mzXML`

> ⚠️ **重要约定**：
> - 组名中**不得包含数字**。例如 `Dose10mg1.mzXML` ❌
> - 组名必须与 `CONTROL_GROUP` 和 `MODEL_GROUP` 参数完全匹配
> - 每组至少 3 个生物学重复（建议 ≥ 5 个以获得可靠的 FDR 校正值）

### 5.3 内部数据库（可选）

若有自建代谢物数据库，将 `.msp` 文件放入 `DB_DIR` 指定的目录。数据库需包含：
- MS1 精确质量
- MS2 碎片谱
- 化合物名称和 ID

---

## 6. 参数设置

打开 `MetaboFlow_v1.r`，修改 **User Parameters** 段（约第 130 行）：

```r
WORK_DIR       <- "path/to/your/data"        # mzXML 文件所在目录
POLARITY       <- "positive"                  # "positive" 或 "negative"
ORGANISM       <- "dre"                       # KEGG 物种代码
LOGFC_CUTOFF   <- 0.176                       # log10 FC 阈值
ALPHA          <- 0.05                        # FDR 校正 P 值阈值
CONTROL_GROUP  <- "control"                   # 对照组名（须匹配文件名前缀）
MODEL_GROUP    <- "DrugA"                     # 实验组名（须匹配文件名前缀）
DB_DIR         <- "path/to/your/database"     # 内部数据库路径

## 通路图设置
TOP_N_PATHWAYS <- 0                           # 图中最多显示通路数（0=全部显著）
PATHWAY_FIG_W  <- 7                           # 通路图宽度（英寸）
PATHWAY_FIG_H  <- 5                           # 通路图高度（英寸）
SUBFIG_MODE    <- FALSE                       # 小子图模式（更大字体+紧凑布局）
```

### 参数详解

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `WORK_DIR` | — | 数据目录，包含所有 .mzXML 文件 |
| `POLARITY` | `"positive"` | 质谱极性模式：`"positive"` 或 `"negative"` |
| `ORGANISM` | `"dre"` | KEGG 物种代码，决定 WF3 使用的通路库。常用代码见下表 |
| `LOGFC_CUTOFF` | `0.176` | log₁₀ 倍数变化阈值。0.176 = 1.5 倍变化，0.301 = 2 倍变化 |
| `ALPHA` | `0.05` | FDR 校正后 P 值筛选阈值 |
| `CONTROL_GROUP` | `"control"` | 对照组名称，须与 .mzXML 文件名前缀完全一致 |
| `MODEL_GROUP` | `"MethiocarbA"` | 实验/药物处理组名称，须与文件名前缀一致 |
| `DB_DIR` | — | 自建代谢物数据库目录路径 |
| `MS1_PPM` | `15` | MS1 质量偏差容差（ppm） |
| `PEAK_WIDTH` | `c(5, 30)` | 色谱峰宽范围（秒） |
| `SN_THRESH` | `5` | 信噪比阈值 |
| `NOISE_LEVEL` | `500` | 仪器噪声水平 |
| `MIN_FRACTION` | `0.5` | 色谱峰在样本中最低出现比例 |
| `NORM_METHOD` | `"median"` | 归一化方法：`"median"` / `"mean"` / `"sum"` / `"pqn"` |
| `TOP_N_PATHWAYS` | `0` | 通路图中最多显示的通路数量。0=显示全部显著通路 |
| `PATHWAY_FIG_W` | `7` | 通路富集图宽度（英寸）。论文子图建议 3.5 |
| `PATHWAY_FIG_H` | `5` | 通路富集图高度（英寸）。论文子图建议 3 |
| `SUBFIG_MODE` | `FALSE` | 小子图模式。设为 `TRUE` 时自动放大字体以适应论文拼图 |

### 非特异性通路过滤

MetaboFlow 自动过滤以下过于宽泛的通路（几乎在任何数据集中都会显著）：
- Metabolic pathways、Biosynthesis of secondary metabolites、Carbon metabolism 等
- 通路内代谢物数 > 150 的超大通路

过滤后结果保存为 `*_filtered.xlsx`，原始全部显著结果保存为 `*.xlsx`。图表默认使用过滤后数据。

### 常用 KEGG 物种代码

| 代码 | 物种 |
|------|------|
| `hsa` | 人 (Homo sapiens) |
| `mmu` | 小鼠 (Mus musculus) |
| `rno` | 大鼠 (Rattus norvegicus) |
| `dre` | 斑马鱼 (Danio rerio) |
| `dme` | 果蝇 (Drosophila melanogaster) |
| `cel` | 线虫 (Caenorhabditis elegans) |
| `ath` | 拟南芥 (Arabidopsis thaliana) |
| `osa` | 水稻 (Oryza sativa) |

完整物种代码列表：https://www.genome.jp/kegg/catalog/org_list.html

---

## 7. 运行方式

### RStudio 运行

1. 用 RStudio 打开 `MetaboFlow_v1.r`
2. 修改 User Parameters 段的参数
3. 全选运行：`Ctrl+Alt+R`（Windows/Linux）或 `Cmd+Option+R`（macOS）

### 命令行运行

```bash
# 激活 conda 环境
conda activate metaboflow

# 运行
Rscript MetaboFlow_v1.r
```

### 运行过程

MetaboFlow 会按以下顺序执行：

1. **依赖检查** — 自动安装缺失的 R 包
2. **色谱峰提取** — XCMS 峰检测与对齐
3. **归一化** — 中位数/均值/PQN 归一化
4. **代谢物注释** — MS1/MS2 匹配内部数据库
5. **差异分析** — limma 线性模型，自动 P 值策略选择
6. **结果导出** — 全部代谢物列表、差异代谢峰、火山图
7. **WF1** — SMPDB 通路富集（tidymass）
8. **WF2** — MSEA 代谢物集富集（MetaboAnalystR）
9. **WF3** — KEGG 通路富集（KEGGREST + Fisher）
10. **WF4** — 定量富集分析（globaltest）
11. **可视化** — PCA 图、火山图、热图、箱线图、通路气泡图

---

## 8. 输出文件说明

运行完成后，所有结果存放在 `Result/` 目录下：

```
Result/
├── PCA_scores.pdf/tiff              # PCA 得分图
├── 所有代谢物.csv                    # 全部注释代谢物列表
├── 差异代谢峰/                       # 差异特征
│   ├── *差异峰.csv                   # 差异峰列表（含 FC、P 值）
│   └── *差异代谢峰.pdf/tiff          # 火山图
├── 差异代谢物/                       # 通路分析结果
│   ├── smpdb_*.xlsx                 # WF1: SMPDB 富集结果表
│   ├── smpdb_*.pdf/tiff             # WF1: SMPDB 气泡图
│   ├── msea_*.xlsx                  # WF2: MSEA 富集结果表
│   ├── msea_*.pdf/tiff              # WF2: MSEA 气泡图
│   ├── kegg_*.xlsx                  # WF3: KEGG 富集结果表
│   ├── kegg_metabolome_view_*.pdf   # WF3: KEGG 代谢组视图
│   ├── qea_*.xlsx                   # WF4: QEA 定量富集结果表
│   ├── qea_*.pdf/tiff               # WF4: QEA 气泡图
│   ├── heatmap_*.pdf/tiff           # 聚类热图
│   └── summary_*.xlsx               # 运行参数汇总
└── Boxplot/                         # 单一代谢物箱线图
    └── *.pdf/tiff                   # 每个差异代谢物一张
```

### 结果表字段说明

#### 通路富集表（WF1–WF4）

| 字段 | 说明 |
|------|------|
| `pathway_name` | 通路名称 |
| `p_value` | 原始 P 值 |
| `p_value_adjust` / `FDR` | BH 校正后 P 值 |
| `mapped_number` / `hits` | 比中的差异代谢物数 |
| `all_number` / `total` | 通路内总代谢物数 |
| `mapped_id` | 比中的代谢物 ID 列表 |

---

## 9. 图表标准

所有图表遵循 Nature 投稿标准：

| 属性 | 规格 |
|------|------|
| **字体** | Arial，正文 7–9 pt |
| **输出格式** | PDF（矢量）+ TIFF（300 DPI，LZW 压缩） |
| **配色** | NPG 调色板：红 `#E64B35`、蓝 `#3C5488`、青 `#4DBBD5`、绿 `#00A087` |
| **尺寸** | 单栏 5×5 英寸，双栏 7×5 英寸 |
| **网格** | 无背景网格线 |
| **边框** | 黑色实线边框，0.6 pt |
| **刻度** | 黑色，0.4 pt |

---

## 10. 常见问题与解决方案

### Q1: tidymass 安装失败，提示 R 版本不满足

```
ERROR: this R is version X.X.X, package 'masstools' requires R >= 4.5
```

**原因**: tidymass 的核心依赖 masstools 要求 R ≥ 4.5.0。

**解决方案**: 升级 R 到 4.5.0 或更高版本。

```bash
# conda 方案
conda install -c conda-forge r-base=4.5.3

# 或新建环境
conda create -n metaboflow -c conda-forge r-base=4.5.3
```

### Q2: MetaboAnalystR `InitDataObjects` 报错

```
Error: promise already under evaluation: recursive default argument reference
```

**原因**: MetaboAnalystR 4.x 的 `InitDataObjects()` 函数存在默认参数递归引用 bug。

**解决方案**: MetaboFlow v1.0 已内置修复，会自动传入 `default.dpi = 72` 参数。无需用户操作。

### Q3: KEGG 下载超时

**原因**: WF3 需要通过网络从 KEGG API 实时获取通路信息。

**解决方案**:
- 检查网络连接
- MetaboFlow 已设置 120 秒超时
- 若在中国大陆使用，可能需要代理

### Q4: 所有 adj.P.Val 都 > 0.05

**原因**: 小样本量（每组 ≤ 3 个）时 FDR 校正过于保守，导致校正后 P 值全部不显著。

**解决方案**: MetaboFlow 会自动检测此情况并回退使用原始 P 值（raw P.Value）。日志中会输出提示信息。建议在实验设计中尽量增加生物学重复数（每组 ≥ 5 个）。

### Q5: WF2/WF4 提示 MetaboAnalystR 不可用

**原因**: MetaboAnalystR 安装失败（常见于依赖冲突）。

**解决方案**:
1. WF1 和 WF3 仍正常运行（优雅降级）
2. 手动安装 MetaboAnalystR：
```r
remotes::install_github("xia-lab/MetaboAnalystR", build_vignettes = FALSE)
```

### Q6: 首次运行时间过长

**原因**: 需要下载安装约 30 个 R 包及其依赖。

**解决方案**: 正常现象，首次运行需 20–40 分钟。后续运行无需重新安装。

---

## 11. 引用

使用 MetaboFlow 进行研究时，请引用以下文献：

- **tidymass**: Shen X, et al. *TidyMass an object-oriented reproducible analysis framework for LC-MS data.* Nature Communications, 2022.
- **MetaboAnalystR**: Pang Z, et al. *MetaboAnalystR 3.0: Toward an Optimized Workflow for Global Metabolomics.* Metabolites, 2020.
- **limma**: Ritchie ME, et al. *limma powers differential expression analyses for RNA-sequencing and microarray studies.* Nucleic Acids Research, 2015.
- **globaltest**: Goeman JJ, et al. *A global test for groups of genes: testing association with a clinical outcome.* Bioinformatics, 2004.
- **KEGGREST**: Tenenbaum D, Maintainer B. *KEGGREST: Client-side REST access to KEGG.* Bioconductor.

---

*MetaboFlow v1.0 — MIT License*

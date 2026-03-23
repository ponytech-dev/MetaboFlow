# MetaboFlow v1.0

**Untargeted Metabolomics Quad-Workflow Integrated Pipeline**

**非靶向代谢组学四工作流集成分析系统**

[![R](https://img.shields.io/badge/R-%E2%89%A54.5.0-276DC3.svg)](https://cran.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Overview / 概述

MetaboFlow is an R-based end-to-end pipeline for untargeted LC-MS metabolomics, integrating feature extraction, normalization, differential analysis, metabolite annotation, and **four parallel pathway enrichment workflows** (3× ORA + 1× QEA) for cross-validation. All figures are rendered to **Nature publication standards**.

MetaboFlow 是一套基于R语言的非靶向LC-MS代谢组学全流程分析系统，集成了特征提取、归一化、差异分析、代谢物注释，以及**四个并行通路富集工作流**（3个ORA + 1个QEA）用于交叉验证。所有图表按**Nature论文投稿标准**渲染。

## Four Workflows / 四个工作流

| Workflow | Type | Engine | Database | Strength |
|----------|------|--------|----------|----------|
| **WF1**: SMPDB Pathway Enrichment | ORA | tidymass `enrich_hmdb` | SMPDB/HMDB | Seamless tidymass integration |
| **WF2**: MSEA | ORA | MetaboAnalystR | SMPDB metabolite sets | Hypergeometric test, curated sets |
| **WF3**: KEGG Pathway Enrichment | ORA | KEGGREST + Fisher | KEGG species-specific | Real-time KEGG data, hypergeometric test |
| **WF4**: QEA Quantitative Enrichment | QEA | globaltest | SMPDB pathway | Full concentration matrix, **GlobalTest** |

## System Requirements / 系统要求

### Operating System / 操作系统

- macOS 12+ (Monterey or later)
- Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- Windows 10/11

### R Environment / R 环境

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **R** | **≥ 4.5.0** | tidymass requires R ≥ 4.5; recommended: R 4.5.3 |
| **RStudio** | ≥ 2024.04 | Recommended for interactive use |
| **BiocManager** | ≥ 1.30.22 | Auto-installed by MetaboFlow |

### Hardware / 硬件

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB+ (large datasets) |
| Disk | 5 GB (for R packages) | 10 GB+ |
| CPU | 4 cores | 8+ cores (parallel peak extraction) |
| Internet | Required for first run | Package download + KEGG API |

### R Package Dependencies / R包依赖

MetaboFlow auto-installs all dependencies on first run. The complete dependency list:

**CRAN packages:**
- `tidyverse`, `openxlsx`, `ggrepel`, `pheatmap`, `ggpubr`, `ggsci`, `patchwork`
- `remotes`, `Cairo`, `qs`, `survival`

**Bioconductor packages:**
- Core: `Biobase`, `limma`, `KEGGREST`, `globaltest`
- XCMS pipeline: `xcms`, `MSnbase`, `BiocParallel`
- Additional: `impute`, `pcaMethods`, `preprocessCore`, `genefilter`, `sva`, `KEGGgraph`, `multtest`, `RBGL`, `Rgraphviz`, `edgeR`, `fgsea`

**GitHub/GitLab packages:**
- `tidymass` (GitLab: tidymass/tidymass) — WF1 + upstream processing
- `MetaboAnalystR` (GitHub: xia-lab/MetaboAnalystR) — WF2

### Environment Setup / 环境配置

**Option 1: conda (recommended)**
```bash
# Create environment with R 4.5.3
conda create -n metaboflow -c conda-forge r-base=4.5.3
conda activate metaboflow

# Launch R and run MetaboFlow — packages auto-install on first run
Rscript MetaboFlow_v1.r
```

**Option 2: System R**
Download and install R ≥ 4.5.0 from [CRAN](https://cran.r-project.org/). Open RStudio, then run MetaboFlow_v1.r. All packages will be auto-installed.

**Option 3: Docker (coming soon)**

> ⚠️ **Important**: First run may take 20-40 minutes for package installation. Subsequent runs start immediately.

## Features / 特色

- **One input, four outputs** — single mzXML input triggers all four pathway analyses
- **Auto-installation** — all dependencies (CRAN, Bioconductor, tidymass, MetaboAnalystR) auto-detected and installed
- **Graceful degradation** — if tidymass or MetaboAnalystR fails to install, available workflows still run
- **Nature-quality figures** — NPG color palette, Arial font, dual PDF vector + TIFF 300 DPI output
- **HMDB ID normalization** — automatically converts old 7-digit to new 11-digit format
- **Smart P-value selection** — uses FDR-corrected `adj.P.Val` when possible; falls back to raw `P.Value` for small sample sizes (n ≤ 3)
- **Bilingual comments** — all code comments in both Chinese and English
- **Non-specific pathway filter** — auto-removes overly broad pathways (e.g., "Metabolic pathways", "ABC transporters"); outputs both full and filtered results
- **Sub-figure mode** — `SUBFIG_MODE=TRUE` increases font size for small paper panels (3.5×3 in); `TOP_N_PATHWAYS` controls how many pathways to show

## Quick Start / 快速开始

1. Place all `.mzXML` files in one directory, following the naming convention below
2. Open `MetaboFlow_v1.r` in RStudio
3. Modify the **User Parameters** section (line ~130):
   ```r
   WORK_DIR       <- "path/to/your/data"
   POLARITY       <- "positive"    # or "negative"
   ORGANISM       <- "dre"         # dre=zebrafish, hsa=human, mmu=mouse
   LOGFC_CUTOFF   <- 0.176         # 1.5-fold change
   ALPHA          <- 0.05          # FDR threshold
   CONTROL_GROUP  <- "control"     # must match filename prefix
   MODEL_GROUP    <- "DrugA"       # must match filename prefix
   DB_DIR         <- "path/to/your/inhouse_database"
   ```
4. Run the entire script (`Ctrl+Alt+R` in RStudio, or `Rscript MetaboFlow_v1.r`)

## File Naming Convention / 文件命名规则

```
[GroupName][Number].mzXML
```

Examples:
- `control1.mzXML`, `control2.mzXML`, `control3.mzXML`
- `TreatmentA1.mzXML`, `TreatmentA2.mzXML`, `TreatmentA3.mzXML`

> ⚠️ Group names must NOT contain digits. Do not use `Dose10mg1.mzXML`.

## Output Structure / 输出结构

```
Result/
├── PCA_scores.pdf/tiff              # PCA scores plot
├── 所有代谢物.csv                    # All annotations
├── 差异代谢峰/                       # Differential features
│   ├── *差异峰.csv                   # Feature lists
│   └── *差异代谢峰.pdf/tiff          # Volcano plots
├── 差异代谢物/                       # Pathway analysis
│   ├── smpdb_*.xlsx/pdf/tiff        # WF1: SMPDB enrichment (ORA)
│   ├── msea_*.xlsx/pdf/tiff         # WF2: MSEA enrichment (ORA)
│   ├── kegg_*.xlsx                  # WF3: KEGG enrichment (ORA)
│   ├── kegg_metabolome_view_*.pdf   # WF3: Enrichment bubble plot
│   ├── qea_*.xlsx/pdf/tiff          # WF4: Quantitative enrichment (QEA)
│   ├── *_filtered.xlsx              # Filtered results (non-specific pathways removed)
│   ├── heatmap_*.pdf/tiff           # Clustered heatmaps
│   └── summary_*.xlsx              # Parameter summary
└── Boxplot/                         # Per-metabolite boxplots
```

## Key Parameters / 关键参数

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LOGFC_CUTOFF` | 0.176 | log₁₀ FC threshold (0.176 = 1.5×, 0.301 = 2×) |
| `ALPHA` | 0.05 | FDR-adjusted p-value threshold |
| `ORGANISM` | "dre" | KEGG organism code ([full list](https://www.genome.jp/kegg/catalog/org_list.html)) |
| `MS1_PPM` | 15 | MS1 mass tolerance (ppm) |
| `PEAK_WIDTH` | c(5,30) | Chromatographic peak width range (sec) |
| `SN_THRESH` | 5 | Signal-to-noise ratio threshold |
| `NOISE_LEVEL` | 500 | Instrument noise level |
| `MIN_FRACTION` | 0.5 | Minimum fraction of samples a peak must appear in |
| `NORM_METHOD` | "median" | Normalization method ("median", "mean", "sum", "pqn") |
| `CONTROL_GROUP` | "control" | Control group name (must match filename prefix) |
| `MODEL_GROUP` | "MethiocarbA" | Model/treatment group name (must match filename prefix) |
| `TOP_N_PATHWAYS` | 0 | Max pathways in enrichment plots (0 = all significant) |
| `PATHWAY_FIG_W` | 7 | Pathway figure width (inches) |
| `PATHWAY_FIG_H` | 5 | Pathway figure height (inches) |
| `SUBFIG_MODE` | FALSE | Small sub-figure mode: larger text + compact layout for paper panels |
| **`FILTER_NONSPECIFIC`** | **TRUE** | **Auto-filter non-specific pathways (e.g., "Metabolic pathways"). Set FALSE to disable** |

## Figure Standards / 图表标准

All figures follow Nature submission guidelines:
- **Font**: Arial, 7–9 pt body text
- **Format**: Dual output — PDF (vector) + TIFF (300 DPI, LZW compression)
- **Colors**: NPG palette (`#E64B35` red, `#3C5488` blue, `#4DBBD5` cyan, `#00A087` green)
- **Dimensions**: Single-column 5×5 in, double-column 7×5 in

## Troubleshooting / 常见问题

### tidymass installation fails
```
ERROR: this R is version X.X.X, package 'masstools' requires R >= 4.5
```
**Solution**: Upgrade R to ≥ 4.5.0. With conda: `conda install -c conda-forge r-base=4.5.3`

### MetaboAnalystR `InitDataObjects` error
```
Error: promise already under evaluation: recursive default argument reference
```
**Solution**: Already fixed in MetaboFlow v1.0. The script passes `default.dpi = 72` explicitly.

### KEGG download timeout
If WF3 hangs during KEGG pathway download, check your internet connection. MetaboFlow sets a 120-second timeout automatically.

### All adj.P.Val > 0.05
This is common with small sample sizes (n ≤ 3 per group). MetaboFlow automatically detects this and falls back to raw P.Value for volcano plots and differential screening.

## Citations / 引用

If you use MetaboFlow in your research, please cite:

- **tidymass**: Shen X, et al. *TidyMass an object-oriented reproducible analysis framework for LC-MS data.* Nature Communications, 2022.
- **MetaboAnalystR**: Pang Z, et al. *MetaboAnalystR 3.0.* Metabolites, 2020.
- **limma**: Ritchie ME, et al. *limma powers differential expression analyses.* Nucleic Acids Research, 2015.
- **globaltest**: Goeman JJ, et al. *A global test for groups of genes.* Bioinformatics, 2004.
- **KEGGREST**: Tenenbaum D, Maintainer B. *KEGGREST: Client-side REST access to KEGG.* Bioconductor.

## Example Results / 示例结果

The `example_results/` directory contains a complete set of analysis outputs from a Methiocarb B zebrafish toxicology experiment:

```
example_results/
├── 01_differential_peaks/     # Volcano plots + differential peak CSV
├── 02_pathway_enrichment/     # Four workflow results
│   ├── WF1_SMPDB/            # SMPDB enrichment (ORA, tidymass)
│   ├── WF2_MSEA/             # MSEA enrichment (ORA, MetaboAnalystR)
│   ├── WF3_KEGG/             # KEGG enrichment (ORA, KEGGREST+Fisher)
│   │   ├── kegg_*.xlsx       # All pathways
│   │   └── kegg_*_filtered.xlsx  # Non-specific pathways removed
│   ├── WF4_QEA/              # Quantitative enrichment (GlobalTest)
│   └── subfig_examples/      # Small sub-figure versions (3.5×3 in)
├── 03_heatmap/                # Clustered heatmaps
├── 04_PCA/                    # PCA scores plots
├── 05_boxplot/                # Representative metabolite boxplots (10 of 183)
└── 06_summary/                # Run parameter summary
```

## Ponytech Ecosystem / 生态系统

| Project | Description |
|---------|-------------|
| [PonyMemory](https://github.com/ponytech-dev/ponymemory) | Autonomous 5-tier memory for AI agents |
| [PonyWriterX](https://github.com/ponytech-dev/ponywriterX) | AI scientific writing platform |
| [PonylabASMS](https://github.com/ponytech-dev/ponylabASMS) | Mass spectrometry analysis |
| [PonyLab](https://github.com/ponytech-dev/ponylab) | AI-native LIMS + ELN |
| [SpaFlow](https://github.com/ponytech-dev/spaflow) | SPA business management |
| [MetaboFlow](https://github.com/ponytech-dev/MetaboFlow) | Metabolomics pipeline |

---

## License / 许可证

MIT License

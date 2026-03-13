# MetaboFlow v1.0

**Untargeted Metabolomics Quad-Workflow Integrated Pipeline**

**非靶向代谢组学四工作流集成分析系统**

---

## Overview / 概述

MetaboFlow is an R-based end-to-end pipeline for untargeted LC-MS metabolomics, integrating feature extraction, normalization, differential analysis, metabolite annotation, and **four parallel pathway enrichment workflows** (3× ORA + 1× QEA) for cross-validation. All figures are rendered to **Nature publication standards**.

MetaboFlow 是一套基于R语言的非靶向LC-MS代谢组学全流程分析系统，集成了特征提取、归一化、差异分析、代谢物注释，以及**四个并行通路富集工作流**（3个ORA + 1个QEA）用于交叉验证。所有图表按**Nature论文投稿标准**渲染。

## Four Workflows / 四个工作流

| Workflow | Type | Engine | Database | Strength |
|----------|------|--------|----------|----------|
| **WF1**: SMPDB Pathway Enrichment | ORA | tidymass `enrich_hmdb` | SMPDB/HMDB | Seamless tidymass integration |
| **WF2**: MSEA | ORA | MetaboAnalystR | SMPDB metabolite sets | Hypergeometric test, updated sets |
| **WF3**: KEGG Topology Analysis | ORA | MetaboAnalystR | KEGG species-specific | **Pathway Impact** topological score |
| **WF4**: QEA Quantitative Enrichment | QEA | MetaboAnalystR | SMPDB pathway | Full concentration matrix, **GlobalTest** |

## Features / 特色

- **One input, four outputs** — single mzXML input triggers all four pathway analyses
- **Auto-installation** — all dependencies (CRAN, Bioconductor, tidymass, MetaboAnalystR) auto-detected and installed
- **Nature-quality figures** — NPG color palette, Arial font, dual PDF vector + TIFF 300 DPI output
- **HMDB ID normalization** — automatically converts old 7-digit to new 11-digit format
- **FDR-corrected statistics** — uses `adj.P.Val` instead of raw p-value for differential screening
- **Bilingual comments** — all code comments in both Chinese and English

## Quick Start / 快速开始

1. Place all `.mzXML` files in one directory
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
4. Run the entire script (`Ctrl+Alt+R` in RStudio)

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
│   ├── *差异峰.csv                   # Feature lists (adj.P.Val filtered)
│   └── *差异代谢峰.pdf/tiff          # Volcano plots
├── 差异代谢物/                       # Pathway analysis
│   ├── smpdb_*.xlsx/pdf/tiff        # WF1: SMPDB enrichment (ORA)
│   ├── msea_*.xlsx/pdf/tiff         # WF2: MSEA enrichment (ORA)
│   ├── kegg_*.xlsx                  # WF3: KEGG topology (ORA)
│   ├── kegg_metabolome_view_*.pdf   # WF3: Impact scatter plot
│   ├── qea_*.xlsx/pdf/tiff          # WF4: Quantitative enrichment (QEA)
│   ├── heatmap_*.pdf/tiff           # Heatmaps
│   └── summary_*.xlsx              # Parameter summary
└── Boxplot/                         # Per-metabolite boxplots
```

## Key Parameters / 关键参数

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LOGFC_CUTOFF` | 0.176 | log₁₀ FC threshold (0.176 = 1.5×, 0.301 = 2×) |
| `ALPHA` | 0.05 | FDR-adjusted p-value threshold |
| `ORGANISM` | "dre" | KEGG organism code |
| `MS1_PPM` | 15 | MS1 mass tolerance (ppm) |
| `PEAK_WIDTH` | c(5,30) | Chromatographic peak width range (sec) |
| `NORM_METHOD` | "median" | Normalization method |
| `CONTROL_GROUP` | "control" | Control group name (must match filename prefix) |
| `MODEL_GROUP` | "MethiocarbA" | Model/treatment group name (must match filename prefix) |

## Figure Standards / 图表标准

All figures follow Nature submission guidelines:
- **Font**: Arial, 7–9 pt body text
- **Format**: Dual output — PDF (vector) + TIFF (300 DPI, LZW compression)
- **Colors**: NPG palette (`#E64B35` red, `#3C5488` blue, `#4DBBD5` cyan, `#00A087` green)
- **Dimensions**: Single-column 5×5 in, double-column 7×5 in

## Requirements / 系统要求

- R ≥ 4.2.0
- Windows 10/11, macOS, or Linux
- RAM ≥ 8 GB (16 GB recommended for large datasets)
- Internet connection for first-run package installation

## Citations / 引用

If you use MetaboFlow in your research, please cite:

- **tidymass**: Shen X, et al. *TidyMass an object-oriented reproducible analysis framework for LC-MS data.* Nature Communications, 2022.
- **MetaboAnalystR**: Pang Z, et al. *MetaboAnalystR 3.0.* Metabolites, 2020.
- **limma**: Ritchie ME, et al. *limma powers differential expression analyses.* Nucleic Acids Research, 2015.

## License / 许可证

MIT License

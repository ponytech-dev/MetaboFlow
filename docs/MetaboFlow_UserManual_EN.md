# MetaboFlow v1.0 User Manual

**Untargeted Metabolomics Quad-Workflow Integrated Pipeline**

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Four Workflows](#2-four-workflows)
3. [System Requirements](#3-system-requirements)
4. [Installation & Setup](#4-installation--setup)
5. [Input Data Requirements](#5-input-data-requirements)
6. [Parameter Configuration](#6-parameter-configuration)
7. [Running MetaboFlow](#7-running-metaboflow)
8. [Output Files](#8-output-files)
9. [Figure Standards](#9-figure-standards)
10. [Troubleshooting](#10-troubleshooting)
11. [Citations](#11-citations)

---

## 1. Introduction

MetaboFlow is an R-based end-to-end pipeline for untargeted LC-MS metabolomics. It integrates feature extraction, normalization, differential analysis, metabolite annotation, and **four parallel pathway enrichment workflows** (3× ORA + 1× QEA) for cross-validation. All figures are rendered to **Nature publication standards**.

Key features:

- **One input, four outputs** — A single run triggers all four independent pathway analysis methods
- **Auto-dependency management** — All CRAN, Bioconductor, tidymass, and MetaboAnalystR packages are automatically installed on first run
- **Graceful degradation** — If tidymass or MetaboAnalystR fails to install, available workflows still run
- **Nature-quality figures** — NPG color palette, Arial font, dual PDF vector + TIFF 300 DPI output
- **HMDB ID normalization** — Automatically converts old 7-digit to new 11-digit format
- **Smart P-value selection** — Auto-detects FDR-corrected P-value availability; falls back to raw P-value for small sample sizes (n ≤ 3)
- **Bilingual comments** — All code comments in both Chinese and English

---

## 2. Four Workflows

| Workflow | Type | Engine | Database | Strength |
|----------|------|--------|----------|----------|
| **WF1**: SMPDB Pathway Enrichment | ORA | tidymass `enrich_hmdb` | SMPDB/HMDB | Seamless tidymass integration |
| **WF2**: MSEA | ORA | MetaboAnalystR | SMPDB metabolite sets | Hypergeometric test, curated sets |
| **WF3**: KEGG Pathway Enrichment | ORA | KEGGREST + Fisher's exact test | KEGG species-specific | Real-time KEGG data, hypergeometric test |
| **WF4**: QEA Quantitative Enrichment | QEA | globaltest | SMPDB pathways | Full concentration matrix, GlobalTest statistic |

### Workflow Details

**WF1 — SMPDB Pathway Enrichment (tidymass)**
Uses tidymass `enrich_hmdb()` to perform over-representation analysis (ORA) against the SMPDB database using HMDB IDs. Fully compatible with the tidymass upstream processing pipeline.

**WF2 — MSEA (MetaboAnalystR)**
Performs Metabolite Set Enrichment Analysis using MetaboAnalystR's curated SMPDB metabolite sets with a hypergeometric test.

**WF3 — KEGG Pathway Enrichment (KEGGREST + Fisher)**
Retrieves species-specific KEGG pathway information in real time via the KEGGREST API. Maps differential metabolite KEGG IDs to pathways and performs Fisher's exact test for enrichment. Supports all KEGG-cataloged organisms via the `ORGANISM` parameter.

**WF4 — Quantitative Enrichment Analysis (globaltest)**
Unlike the list-based ORA methods (WF1–3), WF4 uses the full concentration/abundance matrix. For each pathway, it runs the `gt()` global test, which better leverages quantitative information.

---

## 3. System Requirements

### 3.1 Operating System

| OS | Minimum Version |
|----|-----------------|
| macOS | 12 (Monterey) or later |
| Ubuntu | 20.04+ |
| Debian | 11+ |
| CentOS | 8+ |
| Windows | 10/11 |

### 3.2 R Environment

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **R** | **≥ 4.5.0** (required) | tidymass requires R ≥ 4.5; recommended: R 4.5.3 |
| **RStudio** | ≥ 2024.04 | Recommended for interactive use, not required |
| **BiocManager** | ≥ 1.30.22 | Auto-installed by MetaboFlow |

> ⚠️ **Important**: R version **must be ≥ 4.5.0**. The tidymass core component `masstools` strictly requires R ≥ 4.5. Lower R versions will fail to install tidymass (WF1 unavailable).

### 3.3 Hardware

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB+ (large datasets) |
| Disk | 5 GB (for R packages) | 10 GB+ |
| CPU | 4 cores | 8+ cores (parallel peak extraction) |
| Internet | Required for first run | Package download + KEGG API queries |

### 3.4 R Package Dependencies

MetaboFlow **auto-detects and installs** all dependencies on first run. Complete dependency list:

#### CRAN Packages

| Package | Purpose |
|---------|---------|
| `tidyverse` | Data wrangling and visualization framework |
| `openxlsx` | Excel file I/O |
| `ggrepel` | Non-overlapping plot labels |
| `pheatmap` | Clustered heatmaps |
| `ggpubr` | Publication-ready plots |
| `ggsci` | Nature/Science color palettes |
| `patchwork` | Plot composition |
| `remotes` | GitHub/GitLab package installation |
| `Cairo` | High-quality graphics device |
| `qs` | Fast serialization (MetaboAnalystR dependency) |
| `survival` | Survival analysis (MetaboAnalystR dependency) |

#### Bioconductor Packages

| Package | Purpose |
|---------|---------|
| `Biobase` | Bioinformatics base infrastructure |
| `limma` | Linear model differential analysis |
| `KEGGREST` | KEGG API client (WF3) |
| `globaltest` | Global test (WF4) |
| `xcms` | Chromatographic peak extraction and alignment |
| `MSnbase` | Mass spectrometry data structures |
| `BiocParallel` | Parallel computation framework |
| `impute` | Missing value imputation |
| `pcaMethods` | PCA analysis |
| `preprocessCore` | Data preprocessing |
| `genefilter` | Feature filtering |
| `sva` | Batch effect correction |
| `KEGGgraph` | KEGG graph structures |
| `multtest` | Multiple testing correction |
| `RBGL` | Graph algorithms |
| `Rgraphviz` | Graph visualization |
| `edgeR` | Differential expression |
| `fgsea` | Fast gene set enrichment |

#### GitHub/GitLab Packages

| Package | Source | Purpose |
|---------|--------|---------|
| `tidymass` | GitLab: tidymass/tidymass | WF1 + upstream processing |
| `MetaboAnalystR` | GitHub: xia-lab/MetaboAnalystR | WF2 + WF4 pathway library |

---

## 4. Installation & Setup

### Option 1: conda (Recommended)

```bash
# 1. Create environment with R 4.5.3
conda create -n metaboflow -c conda-forge r-base=4.5.3

# 2. Activate environment
conda activate metaboflow

# 3. Run MetaboFlow (auto-installs all dependencies on first run)
Rscript MetaboFlow_v1.r
```

> ⚠️ First run takes **20–40 minutes** for package installation. Subsequent runs start immediately.

### Option 2: System R

1. Download and install R ≥ 4.5.0 from [CRAN](https://cran.r-project.org/)
2. (Optional) Install RStudio
3. Open RStudio or terminal, run `Rscript MetaboFlow_v1.r`
4. All dependencies are auto-installed on first run

### Option 3: Docker (Coming Soon)

### Auto-Installation Process

MetaboFlow's auto-installer:

1. Checks R version ≥ 4.5.0
2. Installs/upgrades BiocManager
3. Installs CRAN packages, then Bioconductor packages
4. Installs tidymass from GitLab
5. Installs MetaboAnalystR from GitHub
6. If any package fails, marks the corresponding workflow as unavailable and continues
7. Prints a summary of available workflows

---

## 5. Input Data Requirements

### 5.1 File Format

- All sample `.mzXML` files in a **single directory**
- Supports positive and negative ion modes (set via `POLARITY` parameter)

### 5.2 File Naming Convention

```
[GroupName][Number].mzXML
```

Examples:
- `control1.mzXML`, `control2.mzXML`, `control3.mzXML`
- `DrugA1.mzXML`, `DrugA2.mzXML`, `DrugA3.mzXML`

> ⚠️ **Important**:
> - Group names must **NOT contain digits**. E.g., `Dose10mg1.mzXML` ❌
> - Group names must exactly match the `CONTROL_GROUP` and `MODEL_GROUP` parameters
> - Minimum 3 biological replicates per group (≥ 5 recommended for reliable FDR correction)

### 5.3 In-House Database (Optional)

If you have a custom metabolite database, place `.msp` files in the `DB_DIR` directory. The database should contain:
- MS1 accurate mass
- MS2 fragmentation spectra
- Compound names and IDs

---

## 6. Parameter Configuration

Open `MetaboFlow_v1.r` and modify the **User Parameters** section (~line 130):

```r
WORK_DIR       <- "path/to/your/data"        # Directory containing .mzXML files
POLARITY       <- "positive"                  # "positive" or "negative"
ORGANISM       <- "dre"                       # KEGG organism code
LOGFC_CUTOFF   <- 0.176                       # log10 FC threshold
ALPHA          <- 0.05                        # FDR-adjusted p-value threshold
CONTROL_GROUP  <- "control"                   # Must match filename prefix
MODEL_GROUP    <- "DrugA"                     # Must match filename prefix
DB_DIR         <- "path/to/your/database"     # In-house database directory

## Pathway plot settings
TOP_N_PATHWAYS <- 0                           # Max pathways in plot (0=all significant)
PATHWAY_FIG_W  <- 7                           # Pathway figure width (inches)
PATHWAY_FIG_H  <- 5                           # Pathway figure height (inches)
SUBFIG_MODE    <- FALSE                       # Small sub-figure mode (larger text)
DB_DIR         <- "path/to/your/database"     # In-house database directory
```

### Parameter Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WORK_DIR` | — | Data directory containing all .mzXML files |
| `POLARITY` | `"positive"` | Mass spec polarity: `"positive"` or `"negative"` |
| `ORGANISM` | `"dre"` | KEGG organism code for WF3 pathway lookup |
| `LOGFC_CUTOFF` | `0.176` | log₁₀ fold-change threshold. 0.176 = 1.5-fold, 0.301 = 2-fold |
| `ALPHA` | `0.05` | FDR-adjusted p-value cutoff |
| `CONTROL_GROUP` | `"control"` | Control group name, must match .mzXML filename prefix |
| `MODEL_GROUP` | `"MethiocarbA"` | Treatment group name, must match filename prefix |
| `DB_DIR` | — | In-house metabolite database directory path |
| `MS1_PPM` | `15` | MS1 mass tolerance (ppm) |
| `PEAK_WIDTH` | `c(5, 30)` | Chromatographic peak width range (seconds) |
| `SN_THRESH` | `5` | Signal-to-noise ratio threshold |
| `NOISE_LEVEL` | `500` | Instrument noise level |
| `MIN_FRACTION` | `0.5` | Minimum fraction of samples a peak must appear in |
| `NORM_METHOD` | `"median"` | Normalization: `"median"` / `"mean"` / `"sum"` / `"pqn"` |
| `TOP_N_PATHWAYS` | `0` | Max pathways displayed in enrichment plots. 0=all significant |
| `PATHWAY_FIG_W` | `7` | Pathway figure width (inches). Use 3.5 for paper sub-figures |
| `PATHWAY_FIG_H` | `5` | Pathway figure height (inches). Use 3 for paper sub-figures |
| `SUBFIG_MODE` | `FALSE` | Small sub-figure mode. When `TRUE`, auto-enlarges fonts for paper panels |
| **`FILTER_NONSPECIFIC`** | **`TRUE`** | **Non-specific pathway filter toggle. Enabled by default; set `FALSE` to disable** |

---

### ⚠️ Non-Specific Pathway Auto-Filter (Key Feature)

> **Design rationale:** In untargeted metabolomics, certain overly broad pathways (e.g., "Metabolic pathways", "ABC transporters") are flagged as significant in **virtually any experimental condition** because they contain a large number of metabolites, making random hits highly likely. These results **lack biological specificity** and can undermine the credibility of pathway analysis when included in publications.

**Default behavior (`FILTER_NONSPECIFIC = TRUE`):**

MetaboFlow automatically removes the following non-specific pathways:

| Filter Type | Rule | Examples |
|-------------|------|----------|
| **Keyword blacklist** | Pathway name matches any of these keywords | Metabolic pathways, Biosynthesis of secondary metabolites, Biosynthesis of amino acids, Carbon metabolism, 2-Oxocarboxylic acid metabolism, Biosynthesis of cofactors, ABC transporters, Protein digestion and absorption, Mineral absorption, Aminoacyl-tRNA biosynthesis |
| **Size-based filter** | Pathway contains >150 total metabolites | Automatically excludes oversized pathways |

**Dual-file output (ensures completeness):**

| File | Content | Use Case |
|------|---------|----------|
| `*.xlsx` | **All** significant pathways (unfiltered) | Complete record for supplementary materials |
| `*_filtered.xlsx` | Filtered, specific pathways only | **For main-text figures** (default plot data source) |

**To disable filtering:**

If your experiment specifically requires retaining broad pathways (e.g., studying global metabolic reprogramming), set:

```r
FILTER_NONSPECIFIC <- FALSE   # Disable non-specific filtering, keep all significant pathways
```

> **Measured effect (MethiocarbB dataset):** WF3 KEGG reduced from 52 significant pathways → 46 (6 broad metabolic pathways removed). WF1/WF2/WF4 SMPDB pathways are inherently more specific and required minimal filtering.

---

### Common KEGG Organism Codes

| Code | Species |
|------|---------|
| `hsa` | Human (Homo sapiens) |
| `mmu` | Mouse (Mus musculus) |
| `rno` | Rat (Rattus norvegicus) |
| `dre` | Zebrafish (Danio rerio) |
| `dme` | Fruit fly (Drosophila melanogaster) |
| `cel` | Nematode (Caenorhabditis elegans) |
| `ath` | Arabidopsis (Arabidopsis thaliana) |
| `osa` | Rice (Oryza sativa) |

Full list: https://www.genome.jp/kegg/catalog/org_list.html

---

## 7. Running MetaboFlow

### RStudio

1. Open `MetaboFlow_v1.r` in RStudio
2. Edit User Parameters section
3. Run entire script: `Ctrl+Alt+R` (Windows/Linux) or `Cmd+Option+R` (macOS)

### Command Line

```bash
conda activate metaboflow
Rscript MetaboFlow_v1.r
```

### Execution Pipeline

MetaboFlow runs the following steps in order:

1. **Dependency check** — Auto-install missing R packages
2. **Peak extraction** — XCMS peak detection and alignment
3. **Normalization** — Median/mean/PQN normalization
4. **Metabolite annotation** — MS1/MS2 matching against in-house database
5. **Differential analysis** — limma linear model with automatic P-value strategy
6. **Data export** — Full metabolite list, differential features, volcano plots
7. **WF1** — SMPDB pathway enrichment (tidymass)
8. **WF2** — MSEA metabolite set enrichment (MetaboAnalystR)
9. **WF3** — KEGG pathway enrichment (KEGGREST + Fisher)
10. **WF4** — Quantitative enrichment analysis (globaltest)
11. **Visualization** — PCA, volcano, heatmap, boxplots, pathway bubble plots

---

## 8. Output Files

All results are saved in the `Result/` directory:

```
Result/
├── PCA_scores.pdf/tiff              # PCA scores plot
├── 所有代谢物.csv                    # All annotated metabolites
├── 差异代谢峰/                       # Differential features
│   ├── *差异峰.csv                   # Feature lists (FC, P-values)
│   └── *差异代谢峰.pdf/tiff          # Volcano plots
├── 差异代谢物/                       # Pathway analysis results
│   ├── smpdb_*.xlsx                 # WF1: SMPDB enrichment table
│   ├── smpdb_*.pdf/tiff             # WF1: SMPDB bubble plot
│   ├── msea_*.xlsx                  # WF2: MSEA enrichment table
│   ├── msea_*.pdf/tiff              # WF2: MSEA bubble plot
│   ├── kegg_*.xlsx                  # WF3: KEGG enrichment table
│   ├── kegg_metabolome_view_*.pdf   # WF3: KEGG metabolome view
│   ├── qea_*.xlsx                   # WF4: QEA enrichment table
│   ├── qea_*.pdf/tiff               # WF4: QEA bubble plot
│   ├── heatmap_*.pdf/tiff           # Clustered heatmap
│   └── summary_*.xlsx               # Run parameter summary
└── Boxplot/                         # Per-metabolite boxplots
    └── *.pdf/tiff                   # One plot per differential metabolite
```

### Result Table Fields

#### Pathway Enrichment Tables (WF1–WF4)

| Field | Description |
|-------|-------------|
| `pathway_name` | Pathway name |
| `p_value` | Raw P-value |
| `p_value_adjust` / `FDR` | BH-corrected P-value |
| `mapped_number` / `hits` | Number of mapped differential metabolites |
| `all_number` / `total` | Total metabolites in pathway |
| `mapped_id` | List of mapped metabolite IDs |

---

## 9. Figure Standards

All figures follow Nature submission guidelines:

| Property | Specification |
|----------|--------------|
| **Font** | Arial, 7–9 pt body text |
| **Format** | Dual output — PDF (vector) + TIFF (300 DPI, LZW compression) |
| **Colors** | NPG palette: red `#E64B35`, blue `#3C5488`, cyan `#4DBBD5`, green `#00A087` |
| **Dimensions** | Single-column 5×5 in, double-column 7×5 in |
| **Grid** | No background grid lines |
| **Border** | Black solid border, 0.6 pt |
| **Tick marks** | Black, 0.4 pt |

---

## 10. Troubleshooting

### Q1: tidymass installation fails — R version too low

```
ERROR: this R is version X.X.X, package 'masstools' requires R >= 4.5
```

**Cause**: The tidymass core dependency `masstools` requires R ≥ 4.5.0.

**Solution**: Upgrade R to 4.5.0 or later.
```bash
# conda
conda install -c conda-forge r-base=4.5.3

# Or create a new environment
conda create -n metaboflow -c conda-forge r-base=4.5.3
```

### Q2: MetaboAnalystR `InitDataObjects` error

```
Error: promise already under evaluation: recursive default argument reference
```

**Cause**: MetaboAnalystR 4.x has a recursive default argument bug in `InitDataObjects()`.

**Solution**: Already fixed in MetaboFlow v1.0 — `default.dpi = 72` is passed explicitly. No user action required.

### Q3: KEGG download timeout

**Cause**: WF3 fetches pathway data from the KEGG API in real time.

**Solution**:
- Check your internet connection
- MetaboFlow sets a 120-second timeout automatically
- If in mainland China, a proxy may be needed

### Q4: All adj.P.Val > 0.05

**Cause**: With small sample sizes (n ≤ 3 per group), FDR correction is overly conservative, resulting in all adjusted P-values above the threshold.

**Solution**: MetaboFlow auto-detects this situation and falls back to raw P-values. A message is logged. For more reliable FDR correction, use ≥ 5 biological replicates per group.

### Q5: WF2/WF4 reports MetaboAnalystR unavailable

**Cause**: MetaboAnalystR installation failed (common with dependency conflicts).

**Solution**:
1. WF1 and WF3 still run normally (graceful degradation)
2. Try manual installation:
```r
remotes::install_github("xia-lab/MetaboAnalystR", build_vignettes = FALSE)
```

### Q6: First run takes very long

**Cause**: ~30 R packages and their dependencies need to be downloaded and installed.

**Solution**: This is expected — first run takes 20–40 minutes. Subsequent runs start immediately.

---

## 11. Citations

When using MetaboFlow in your research, please cite:

- **tidymass**: Shen X, et al. *TidyMass an object-oriented reproducible analysis framework for LC-MS data.* Nature Communications, 2022.
- **MetaboAnalystR**: Pang Z, et al. *MetaboAnalystR 3.0: Toward an Optimized Workflow for Global Metabolomics.* Metabolites, 2020.
- **limma**: Ritchie ME, et al. *limma powers differential expression analyses for RNA-sequencing and microarray studies.* Nucleic Acids Research, 2015.
- **globaltest**: Goeman JJ, et al. *A global test for groups of genes: testing association with a clinical outcome.* Bioinformatics, 2004.
- **KEGGREST**: Tenenbaum D, Maintainer B. *KEGGREST: Client-side REST access to KEGG.* Bioconductor.

---

*MetaboFlow v1.0 — MIT License*

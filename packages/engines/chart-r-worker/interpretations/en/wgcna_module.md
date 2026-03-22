# WGCNA Module-Trait Correlation Heatmap

## Description

The WGCNA (Weighted Gene Co-expression Network Analysis) module-trait heatmap displays Pearson correlation coefficients between metabolite co-expression modules (rows, named by colors such as turquoise, blue, etc.) and phenotypic variables (columns, such as BMI, blood glucose, disease scores). Each cell shows the correlation coefficient and p-value; deeper red indicates stronger positive correlation; deeper blue indicates stronger negative correlation.

## How to Read

- **Deep red cells (strong positive correlation)**: Metabolites in that module are overall positively correlated with that phenotype — as module abundance increases, the phenotype also increases
- **Deep blue cells (strong negative correlation)**: Module abundance increases as the phenotype decreases — e.g., a lipid module negatively correlated with HDL
- **Significant cells (asterisk-marked)**: P-values remain significant after FDR correction — these provide reliable evidence of module-trait associations
- **Hub metabolites**: Within each significant module, the metabolite with the highest kME (module membership score) is the hub — the representative metabolite of that module
- **Multi-trait patterns**: A module simultaneously associated with multiple phenotypes suggests those module metabolites participate in multiple physiological regulatory pathways

## Important Notes

- WGCNA requires a minimum sample size of ≥20; smaller samples produce unstable network construction
- The soft threshold (soft power β) selection significantly affects module count and size — confirm appropriate selection using scale-free topology tests
- Module-trait correlation analysis should report p-values (not just r values) to avoid over-interpreting weak correlations
- WGCNA was originally designed for transcriptomics; biological interpretability in metabolomics requires integration with metabolic pathway knowledge

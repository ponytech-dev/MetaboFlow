# Metabolite-Phenotype Correlation Heatmap

## Description

The metabolite-phenotype correlation heatmap displays Spearman or Pearson correlation coefficients between selected metabolites (rows) and clinical/physiological variables (columns, such as body weight, blood pressure, inflammatory markers, gene expression, etc.). Colors transition from deep blue (strong negative correlation) to deep red (strong positive correlation); each cell is labeled with the r value; significant associations are marked with asterisks (*p<0.05, **p<0.01, ***p<0.001).

## How to Read

- **Deep red cells**: Positive correlation between that metabolite and that clinical indicator — as metabolite concentration increases, the indicator also increases; may indicate a physiological functional association
- **Deep blue cells**: Negative correlation — as metabolite concentration increases, the indicator decreases
- **Row patterns**: A metabolite significantly correlated with multiple phenotypic variables suggests it may be an important functional biomarker
- **Column patterns**: A clinical indicator correlated with multiple metabolites suggests that phenotype is influenced by multiple metabolites collectively
- **Color block clusters**: Regions of similar color may represent a group of metabolites jointly associated with a specific category of clinical indicators

## Important Notes

- Correlation does not equal causation — interpret cautiously in conjunction with biological mechanisms
- Multiple testing correction (FDR) must be applied; without it, many cells will show spurious significance
- Spearman correlation is appropriate for non-normally distributed data; Pearson correlation is suitable for normally distributed data
- With small sample sizes (n<30), correlation coefficients are unstable — report 95% confidence intervals

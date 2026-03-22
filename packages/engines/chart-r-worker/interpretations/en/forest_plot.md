# Forest Plot

## Description

The metabolomics forest plot displays effect sizes (log2FC) and 95% confidence intervals for multiple metabolites in a meta-analysis-inspired style. Each metabolite occupies one row; the center point shows the log2FC estimate; the horizontal line segment shows the CI range; a vertical reference line at log2FC=0 indicates no effect. Metabolites are typically grouped by chemical superclass, with different colors for each class.

## How to Read

- **Center point position**: The point estimate of log2FC; positive values (right of reference line) indicate up-regulation; negative values (left) indicate down-regulation
- **Horizontal line segment (CI)**: Metabolites whose confidence interval does not cross the zero line (entirely on one side) are statistically significant
- **Point size (optional)**: Sometimes point size encodes -log10(adj.p) — larger points indicate greater significance
- **Color grouping**: Different chemical superclasses use distinct colors, making it easy to identify overall trends within specific chemical categories
- **Overall effect (diamond)**: If an aggregate effect size is calculated, it appears as a diamond at the bottom of all metabolite rows

## Important Notes

- The "forest plot" in metabolomics borrows the meta-analysis visual format but is not a true meta-analysis — it does not involve cross-study pooling
- CI width reflects sample size and individual variability; metabolites with very wide CIs have limited statistical power
- Including adj.p values (e.g., FDR correction) in the annotation is recommended so readers can quickly assess significance
- Grouping by chemical class can reveal patterns where "a particular class of metabolites shifts collectively in the same direction"

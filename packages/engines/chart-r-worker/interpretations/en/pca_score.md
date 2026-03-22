# PCA Score Plot

## Description

The PCA score plot is the preferred unsupervised method for quality assessment and sample grouping in metabolomics. It projects the high-dimensional feature matrix onto PC1 and PC2, displaying each sample as a point in two-dimensional space. The percentage of variance explained by each component is annotated, and 95% confidence ellipses are drawn per group.

## How to Read

- **Point positions**: Samples with similar metabolic profiles cluster together; greater distance indicates greater metabolic dissimilarity
- **Ellipses**: 95% confidence intervals per group; overlapping ellipses suggest limited metabolic differences between groups
- **PC1/PC2 variance explained**: Higher percentages indicate more information captured; interpret cautiously when both axes together explain less than 50%
- **QC samples**: Should cluster tightly in the center of the plot; scattered QC points suggest batch effects or instrument drift
- **Outliers**: Samples far outside their group ellipse may be true outliers and should be inspected in the raw data

## Important Notes

- PCA is unsupervised and cannot guarantee group separation; poor separation does not mean no differential metabolites exist
- Strong batch effects can dominate PC1 and mask true biological signals — apply batch correction before interpretation
- Score plot shape is sensitive to the normalization method (Pareto vs. UV scaling); ensure consistent preprocessing

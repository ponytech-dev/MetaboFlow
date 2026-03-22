# Sample Correlation Heatmap

## Description

The sample correlation heatmap displays the pairwise Pearson or Spearman correlation coefficient matrix for all samples. Colors transition from deep blue (low or negative correlation) to deep red (high positive correlation). Both rows and columns are ordered by hierarchical clustering to visually identify sample groupings, batch clusters, and outlier samples.

## How to Read

- **Diagonal**: Always deep red (correlation = 1; each sample is perfectly correlated with itself)
- **Within-group blocks**: Samples from the same experimental group should form deep red squares, indicating consistent metabolic profiles
- **Between-group correlations**: Lighter-colored blocks between different groups indicate greater metabolic dissimilarity
- **Outlier samples**: If a sample shows low correlation with others in its group (light-colored row/column), it should be flagged as a potential outlier
- **Batch clustering**: If samples from different experimental groups but the same batch cluster together, significant batch effects are present

## Important Notes

- Correlation values below 0.9 between samples within the same group are worth investigating; values below 0.8 require thorough follow-up
- This plot is sensitive to data normalization — unnormalized data may show spurious correlations driven by dilution differences
- For large studies (>100 samples), the heatmap becomes crowded; consider scatter plot matrices or subgroup views instead
- Evaluate batch correction effectiveness by comparing pre- and post-correction clustering patterns in the correlation heatmap

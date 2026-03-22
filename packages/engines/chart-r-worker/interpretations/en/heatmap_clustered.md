# Clustered Sample Heatmap

## Description

The clustered heatmap uses color encoding to display the relative abundance of differential metabolites across all samples. Both rows (features) and columns (samples) are ordered by hierarchical clustering, with dendrograms shown alongside. Typically the top N most significant features are selected; deep red indicates high abundance and blue indicates abundance below the mean.

## How to Read

- **Row dendrogram (features)**: Groups metabolites with similar abundance patterns, revealing functionally related metabolite clusters
- **Column dendrogram (samples)**: Groups samples with similar metabolic profiles, validating within-group consistency and between-group separation
- **Color block patterns**: A consistent red or blue block across one group for a set of features indicates a stable, reproducible group difference
- **Top/side annotation bars**: Colored bars indicate sample group, batch, or other metadata for easy cross-referencing

## Important Notes

- The heatmap displays normalized relative abundance (Z-scores), not absolute concentrations
- Changing the Top N threshold alters clustering results — cross-reference with the volcano plot to confirm the full scope of differential metabolites
- High within-group color variability for a feature suggests biological heterogeneity or outlier samples in that group
- Feature names displayed as m/z_RT format indicate those features have not yet been annotated

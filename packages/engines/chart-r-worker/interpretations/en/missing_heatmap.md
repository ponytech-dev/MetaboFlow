# Missing Value Heatmap

## Description

The missing value heatmap displays the distribution pattern of NA values (undetected features) in the feature × sample matrix. Black or dark cells indicate missing values; white or light cells indicate detected values. By visualizing systematic missingness patterns, this plot helps determine the cause of missingness (random vs. structured) and guides the selection of appropriate imputation strategies.

## How to Read

- **Randomly scattered missing values (salt-and-pepper pattern)**: Random distribution suggests low-abundance features not consistently detected — suitable for KNN or minimum-value imputation
- **Entire column missing (one sample)**: That sample may have had an injection failure or data corruption — investigate before deciding whether to include it
- **Entire row missing (one feature)**: That feature was undetected across all samples and should be removed in the filtering step
- **Group-specific missingness**: A feature absent in one group but detected in another may indicate that its concentration is below the detection limit in that group — this can carry biological significance
- **Missingness threshold**: Features should typically be detected in ≥70% of samples; otherwise, filter them out

## Important Notes

- Missing values do not equal zero concentration — in metabolomics, "not detected" usually means below the detection limit
- Group-specific missing features require special handling in differential analysis and should not simply be imputed with 0 or group means
- Samples with more than 30% missing values should typically be excluded from analysis
- The choice of imputation method (minimum value, KNN, random forest, etc.) can substantially affect downstream statistical results

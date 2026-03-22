# OPLS-DA Score Plot + S-Plot Dual Panel

## Description

The OPLS-DA dual panel contains two side-by-side panels: the left shows the OPLS-DA score plot (between-group separation), and the right shows the S-plot (structure-correlation scatter plot). The S-plot displays each feature's contribution to model separation using two axes — covariance (x-axis, reflecting magnitude of change) and correlation coefficient (y-axis, reflecting reliability) — with VIP>1 features highlighted.

## How to Read

- **OPLS-DA score plot**: Separation along t[1] (predictive component) represents true between-group differences; the vertical direction (to[1]) represents within-group orthogonal variation
- **S-plot quadrants**: Upper right = positively correlated high-contribution features driving separation (up-regulated); lower left = negatively correlated features (down-regulated); features near the origin contribute minimally
- **"S" shape**: Ideally, features distribute in an S-curve, with high-contribution features at both ends and low-contribution noise features in the middle
- **VIP>1 highlighted points**: Features exceeding the VIP=1 threshold are generally considered key metabolites with significant classification contribution

## Important Notes

- OPLS-DA requires permutation testing for validation just as PLS-DA does — this step must not be skipped
- Features in the S-plot with simultaneously high covariance AND high correlation hold the greatest biological value
- Using VIP>1 alone for feature selection is too coarse — combine with p-values and fold change for more rigorous filtering
- When sample size is smaller than the number of features (common in metabolomics), overfitting risk is substantial

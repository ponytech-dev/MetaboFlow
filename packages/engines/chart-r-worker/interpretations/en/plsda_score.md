# PLS-DA Score Plot

## Description

The Partial Least Squares Discriminant Analysis (PLS-DA) score plot is a supervised sample grouping visualization that uses class information to maximize between-group separation. The plot shows sample positions on the first two latent variables (LV1/LV2) and annotates model quality metrics: R²X (variance in X explained), R²Y (variance in Y explained), and Q² (cross-validated predictive ability).

## How to Read

- **Sample separation**: Clearer separation between groups indicates more pronounced metabolic profile differences; PLS-DA typically achieves better separation than PCA
- **R²X**: The proportion of feature information used by the model; higher values indicate more complete capture of sample information
- **R²Y**: How well the model explains group labels; higher values indicate stronger association between metabolic features and grouping
- **Q²**: Predictive ability estimated by cross-validation; Q² > 0.5 indicates good predictive power; Q² < 0 indicates overfitting
- **Ellipses**: 95% confidence intervals per group; non-overlapping ellipses indicate significant metabolic discrimination

## Important Notes

- PLS-DA is a supervised method and can produce apparent separation even from random noise — always validate model validity using permutation tests
- Q² should be significantly higher than the Q² distribution obtained from permutation testing; otherwise the model is not valid
- When R²Y >> Q² (gap > 0.3), this suggests overfitting, likely due to insufficient sample size
- PLS-DA score plots are typically followed by VIP lollipop charts to highlight the key metabolites driving group separation

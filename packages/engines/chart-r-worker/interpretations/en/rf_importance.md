# Random Forest Feature Importance Plot

## Description

The random forest feature importance plot displays the ranking of metabolite features contributing most to classification between groups in a machine learning model. It is typically shown as a horizontal bar chart of the top 20–30 features, with the x-axis showing importance metrics — Mean Decrease Accuracy (MDA) and/or Mean Decrease Gini (MDG) — either as dual axes side-by-side or as separate plots.

## How to Read

- **Mean Decrease Accuracy (MDA)**: The drop in model accuracy when a feature is permuted; larger values indicate that feature is more critical for classification
- **Mean Decrease Gini (MDG)**: The average contribution of that feature to reducing node impurity across decision trees; larger values indicate stronger discrimination ability
- **Bar length**: Longer bars indicate higher feature importance; bars are typically ordered from largest to smallest by MDA or MDG
- **Color coding (optional)**: Colors can distinguish up- vs. down-regulated metabolites or chemical superclasses
- **Top features**: The top 5–10 metabolites in the ranking are the most likely candidates for differential biomarkers

## Important Notes

- Random forest feature importance is affected by random seed — set a fixed seed for reproducibility and average results across multiple runs
- Correlated features (metabolites in the same pathway) share importance scores; a feature may rank lower because a correlated feature substitutes for it
- Class imbalance (unequal sample sizes) causes MDG to favor majority-class features — use oversampling or weighting approaches when class imbalance is present
- This plot does not show differential direction — combine with boxplots or fold change analysis to understand each feature's directional change

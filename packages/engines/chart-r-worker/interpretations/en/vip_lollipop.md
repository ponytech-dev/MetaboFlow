# VIP Score Lollipop Chart

## Description

The VIP (Variable Importance in Projection) lollipop chart displays the ranked VIP scores of the top N key features from an OPLS-DA or PLS-DA model. Each feature is represented by a line (stick) and circle (candy); higher VIP values indicate greater contribution to between-group classification. Circle color encodes the log2FC direction (red = up-regulated, blue = down-regulated).

## How to Read

- **Horizontal axis (VIP value)**: Arranged from highest to lowest; VIP=1 dashed line marks the significance threshold
- **Circle color**: Red indicates the feature is up-regulated in the experimental group (positive log2FC); blue indicates down-regulation
- **Feature names (y-axis)**: Annotated features show compound names; unannotated features display m/z_RT format
- **Line length**: Proportional to VIP value; the longest bar corresponds to the most important metabolite in the model
- **Dual interpretation**: Combining color and VIP value enables rapid identification of "high-contribution and up-regulated" vs. "high-contribution and down-regulated" differential biomarkers

## Important Notes

- VIP values are model-dependent; PLS-DA models with different numbers of latent variables can yield substantially different VIP values
- VIP>1 is an empirical threshold; some studies apply VIP>1.5 for more stringent selection
- Always combine VIP results with differential analysis (p-values and fold change) to avoid misidentification from a single method
- If the top VIP features are predominantly unannotated, prioritizing annotation work on those features should come first

# PCA Biplot (Loading Plot)

## Description

The PCA biplot overlays feature loading vectors onto the sample score plot, simultaneously displaying sample distribution and the key feature directions driving that distribution. Each arrow represents one feature; the arrow direction points toward the direction of increasing score for that feature; arrow length reflects the feature's contribution to the principal components.

## How to Read

- **Sample points**: Same interpretation as the PCA score plot — reflect metabolic similarity between samples
- **Feature arrows (loading vectors)**: Longer arrows indicate greater contribution to PCA separation
- **Directional alignment**: Long arrows pointing in the same direction as a group of samples indicate that those features have elevated abundance in that group
- **Perpendicular arrows**: Indicate two features that are uncorrelated in PCA space, likely belonging to different metabolic pathways
- **Opposing arrows**: Represent features that are elevated in one group and reduced in another — classic anti-correlated metabolites

## Important Notes

- When the feature count is large, the biplot becomes cluttered — typically only the top 20–50 most contributing features are labeled
- Loading vector lengths are affected by the normalization method; use caution when comparing across different preprocessing approaches
- The biplot is suited for exploratory analysis; quantitative differences should be confirmed through differential analysis (volcano plot)
- For more precise feature importance ranking, use PLS-DA combined with VIP analysis

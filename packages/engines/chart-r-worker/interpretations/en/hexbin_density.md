# Hexbin Density Plot (m/z-RT Feature Density)

## Description

The hexbin density plot divides the m/z-RT two-dimensional space into uniform hexagonal cells, with each hexagon's color depth reflecting the number of features falling in that region (density). Compared to scatter plots, hexbin clearly visualizes density patterns when thousands of features (>5,000) are present, without the overplotting problem that obscures scatter plots.

## How to Read

- **Dark hexagons**: Regions with the highest feature density — correspond to chemical space where the instrument detects most efficiently
- **Light regions**: Low feature density, possibly indicating reduced detector sensitivity or sparse natural abundance of metabolites in that chemical space
- **Horizontal bands (high density at specific m/z)**: May indicate a concentrated cluster of a specific compound class (e.g., phospholipids) at that m/z range
- **Vertical bands (high density at specific RT)**: Suggests concentrated compound elution at that retention time window, possibly indicating suboptimal chromatographic gradient design
- **Empty zones**: m/z < 100 and m/z > 1200 regions are typically empty, consistent with typical LC-MS metabolomics profiles

## Important Notes

- Hexagon bin size affects visualization quality: too large loses detail, too small creates overly sparse density maps
- This plot is a global quality assessment tool and does not reflect differential analysis results
- Density distributions differ between ion modes (positive/negative) — view separately
- Comparing hexbin plots across batches or experiments quickly reveals changes in method coverage

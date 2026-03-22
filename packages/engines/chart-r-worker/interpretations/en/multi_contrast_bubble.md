# Multi-contrast Bubble Heatmap

## Description

The multi-contrast bubble heatmap simultaneously displays differential patterns across multiple pairwise comparisons (>2 groups). Rows represent features (metabolites); columns represent different contrast combinations (e.g., A vs B, A vs C, B vs C). Within each cell, bubble size corresponds to -log10(adj.p) (statistical significance), and bubble color corresponds to log2FC direction (red = up-regulated, blue = down-regulated).

## How to Read

- **Large bubbles**: The feature is statistically significant in that contrast (small adj.p); larger bubbles indicate greater significance
- **Bubble color**: Red indicates up-regulation of that metabolite in the contrast; blue indicates down-regulation; white or no bubble indicates no significant difference
- **Row pattern (across contrasts)**: If a metabolite shows large red bubbles across all contrasts, it is consistently up-regulated across all group comparisons
- **Column pattern (specific contrast)**: A column with generally large bubbles indicates that contrast has many significant differential metabolites
- **Diagonal patterns**: Some metabolites are significant only in specific contrasts, suggesting condition-specific differential regulation

## Important Notes

- Bubble heatmaps work well for 3–8 contrast combinations; too many contrasts make the figure too crowded
- Pay attention to the direction definition of each contrast (A-B means A relative to B) — the reference group must be clearly stated in the figure legend
- FC values across contrasts cannot be directly compared because they have different reference groups
- Sorting feature rows by chemical class or pathway grouping greatly improves biological interpretability

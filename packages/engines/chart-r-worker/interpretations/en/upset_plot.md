# UpSet Plot (Set Intersection Diagram)

## Description

The UpSet plot visualizes set intersection relationships among differential metabolites across multiple comparisons, and is the preferred alternative to Venn diagrams when handling 3 or more sets. A matrix of dots on the left indicates which sets participate in each intersection; bar charts at the top (or right) show the count of features in each intersection; horizontal bars at the bottom show the total size of each individual set.

## How to Read

- **Vertical bars (intersection bars)**: Each bar represents a specific combination of sets; bar height indicates the number of features unique to that combination
- **Dot matrix connections**: Filled dots connected by lines indicate which sets participate in that intersection; a single dot (no line) represents features unique to that set
- **Tallest vertical bar**: The intersection combination with the most features, often carrying the strongest biological significance
- **Bottom horizontal bars**: Total count of differential features for each individual comparison, reflecting the scale of each contrast
- **Isolated vertical bars (single set)**: Features significant in only one comparison, representing comparison-specific metabolic changes

## Important Notes

- UpSet plot interpretation depends heavily on how sets are defined (thresholds) — different thresholds can substantially change the results
- When the number of sets exceeds 6, the plot becomes complex — focus on the most important comparisons
- Features significant across multiple sets (multi-set intersections) generally have higher biological credibility
- This plot does not show differential direction (up/down-regulation) — combine with volcano plots or heatmaps for directional interpretation

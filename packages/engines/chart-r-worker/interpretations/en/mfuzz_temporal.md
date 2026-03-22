# Mfuzz Temporal Clustering Plot

## Description

The Mfuzz temporal clustering plot is designed for time-series metabolomics experiments. It groups metabolites by temporal expression patterns (e.g., 0h→6h→24h→72h) into N fuzzy clusters (soft clustering), with each cluster displayed in a separate panel. Grey thin lines show individual metabolite trajectories; the colored thick line shows the cluster mean trend (±SD); color depth reflects each metabolite's membership score for that cluster.

## How to Read

- **Mean trend line (colored thick line)**: Represents the typical temporal expression pattern of metabolites in that cluster (rising, falling, peak-then-decline, etc.)
- **Membership color depth**: Dark-colored trajectories indicate high cluster membership (high confidence assignment); light-colored trajectories indicate fuzzy membership (the metabolite may belong to multiple clusters)
- **Number of clusters N**: Must be set in advance based on data characteristics — use silhouette coefficients or other metrics to select the optimal N
- **X-axis (time points)**: Corresponds to the experimental time series; time units should be explicitly labeled
- **Y-axis (normalized abundance)**: Typically Z-scores, not absolute concentrations

## Important Notes

- Fuzzy clustering allows one metabolite to simultaneously belong to multiple clusters, unlike hard clustering methods (e.g., k-means)
- With fewer than 3 time points, Mfuzz clustering has limited value — at least 4 time points are recommended
- The metabolite list from each cluster can be subjected to pathway enrichment to reveal which pathways are activated at which time points
- Initial cluster centers affect final results — set a random seed to ensure reproducibility

# Multi-panel QC Dashboard

## Description

The QC dashboard combines multiple key quality control plots into a 2×2 or 3×2 multi-panel layout, typically including: (1) sample QC intensity boxplot, (2) QC RSD distribution histogram, (3) PCA sample score plot with QC samples highlighted, and (4) missing value proportion bar chart or missing value heatmap. The combined figure provides a comprehensive assessment of overall dataset quality in a single view, ideal as the opening figure of a data analysis report.

## How to Read

- **Panel 1 (intensity boxplot)**: Evaluates injection volume consistency and batch effects; median intensity of QC samples should be stable and consistent across the run
- **Panel 2 (RSD distribution)**: Evaluates feature reproducibility; passing criterion is RSD<20% for >80% of features
- **Panel 3 (PCA plot)**: Evaluates sample grouping quality; QC samples should cluster tightly at the center, with experimental groups separating appropriately
- **Panel 4 (missing values)**: Evaluates data completeness; both sample-level and feature-level missing rates should be within acceptable limits
- **Overall assessment**: Data quality is acceptable for downstream analysis when all four panels pass; investigate immediately if any panel shows anomalies

## Important Notes

- The dashboard enables rapid overall assessment — when problems are identified, examine detailed versions of the individual sub-plots
- Comparing QC Dashboards across different batches or experiments quickly surfaces systematic differences
- The panel combination can be adjusted to match the experimental design; if TIC data is available, it can replace one of the default panels
- Each panel in the dashboard should remain concise, prioritizing a global perspective over excessive detail

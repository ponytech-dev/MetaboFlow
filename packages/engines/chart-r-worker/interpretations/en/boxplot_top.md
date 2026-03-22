# Feature Abundance Distribution Plot (Boxplot / Violin-Box)

## Description

The boxplot or violin-box combination displays the abundance distribution of one or more selected metabolites across experimental groups. Each box shows the median, interquartile range, and outliers; the violin shape represents the full kernel density estimate; Tukey significance brackets and asterisks annotate statistical differences between groups.

## How to Read

- **Center line in box**: Median abundance for that group
- **Box edges**: 25th and 75th percentiles (interquartile range, IQR)
- **Whiskers**: Extend to the maximum/minimum values within 1.5×IQR
- **Scattered dots (beeswarm)**: Individual sample measurements, spread to avoid overplotting
- **Significance brackets**: "\*" p<0.05, "\*\*" p<0.01, "\*\*\*" p<0.001, "ns" = not significant

## Important Notes

- Abundance values are typically log-transformed to improve normality — check the y-axis label to confirm
- Per-group sample size n should be labeled on the plot; interpret statistical conclusions cautiously when n<5
- Outlier data points (dots outside the box) should be traced back to raw data and not removed without justification
- When multiple metabolites are displayed side-by-side, y-axis scales may differ — do not compare absolute values directly across panels

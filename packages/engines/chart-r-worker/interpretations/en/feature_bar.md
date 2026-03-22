# Feature Intensity Bar Chart (Selected Metabolites)

## Description

The feature intensity bar chart displays the mean abundance (bar height) and variability (error bars) of 2–8 key metabolites across experimental groups, with significance brackets and asterisks between groups. This is the most commonly used single-metabolite quantitative figure in metabolomics papers, ideal for highlighting the most significantly differential metabolites in main figures or supplementary panels.

## How to Read

- **Bar height**: Mean signal intensity (or normalized relative abundance) for each group
- **Error bars**: Typically standard error (SE) or standard deviation (SD), reflecting within-group variability
- **Significance asterisks**: Placed above brackets connecting two groups; "\*" p<0.05, "\*\*" p<0.01, "\*\*\*" p<0.001
- **Color groups**: Different colors distinguish experimental groups; the color scheme should be consistent with other figures in the manuscript
- **Y-axis label**: Note whether values are log-transformed to correctly interpret fold differences

## Important Notes

- Bar charts display means and hide distributional shape — when sample size is small (n<10), overlay individual data points to show the underlying distribution
- Error bar type (SD vs. SE) must be specified in the figure legend; SE makes differences appear smaller and should be used carefully
- When multiple metabolites are shown side-by-side, y-axis scales may differ — do not directly compare absolute values
- If a metabolite is extremely elevated in only 1–2 samples rather than being a true group difference, bar charts will obscure this — use boxplots in such cases

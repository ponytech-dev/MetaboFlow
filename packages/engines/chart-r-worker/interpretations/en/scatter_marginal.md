# Scatter Plot with Marginal Distribution

## Description

The marginal distribution scatter plot displays the correlation of log2FC values between two contrasts: the x-axis shows log2FC for contrast 1; the y-axis shows log2FC for contrast 2; each point represents one metabolite. Marginal kernel density curves are displayed above and to the right, revealing the overall FC distribution for each individual contrast. This plot is commonly used in multi-timepoint or multi-treatment comparisons.

## How to Read

- **Upper right quadrant**: Metabolites up-regulated in both contrasts — consistent co-upregulation (synergistic metabolic change)
- **Lower left quadrant**: Metabolites down-regulated in both contrasts — consistent co-downregulation
- **Lower right / upper left quadrants**: Metabolites up-regulated in one contrast but down-regulated in another — antagonistic or temporal metabolic changes
- **Diagonal line (y=x)**: Points on the diagonal indicate identical FC values in both contrasts
- **Marginal distributions**: The density curves above and to the right reflect the width and center of each contrast's FC distribution, enabling quick comparison of overall differential scale

## Important Notes

- Point color can encode chemical class, annotation confidence level, or p-value to add interpretive dimensions
- Points clustered near the origin (0,0) show no significant change in either contrast
- The Pearson correlation coefficient (r) can be annotated on the plot to reflect overall concordance between the two contrasts
- This plot does not directly display p-value information — use it together with volcano plots for comprehensive interpretation

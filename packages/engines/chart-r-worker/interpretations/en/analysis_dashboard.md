# Comprehensive Analysis Dashboard

## Description

The comprehensive analysis dashboard is the standard four-panel combination format for metabolomics main figures: upper left shows the PCA score plot (unsupervised sample grouping); upper right shows the volcano plot (global differential metabolites); lower left shows the top differential metabolites heatmap (expression pattern clustering); lower right shows the pathway enrichment bubble plot (functional annotation). The four panels cover the complete analytical narrative from sample quality → differential discovery → metabolic patterns → functional interpretation.

## How to Read

- **Upper left (PCA)**: Verify whether sample grouping aligns with the experimental design, whether within-group variability is acceptable, and whether any outlier samples are present
- **Upper right (volcano plot)**: Identify the number, distribution, and annotated names of significantly up- and down-regulated metabolites, providing a rapid overview of differential scale
- **Lower left (heatmap)**: Display the cross-sample expression patterns of top differential metabolites, confirming within-group consistency and between-group contrast
- **Lower right (pathway bubble plot)**: Map differential metabolites to functional pathways, answering "which biological processes are affected by these metabolic changes?"
- **Four-panel reading sequence**: Confirm quality via PCA → discover differences via volcano plot → validate patterns via heatmap → interpret function via pathway plot — forming a complete scientific narrative

## Important Notes

- The four-panel dashboard is suited for a single contrast (one experimental group vs. one control group); multiple contrasts should be shown separately
- Panel size ratios should be balanced; a 2×2 equal-area layout or size adjustments based on information density are both appropriate
- Publication-quality figures require font size ≥8pt, resolution ≥300 dpi, and complete legends
- This figure typically serves as Figure 1 or Figure 2 in a manuscript — keep it concise and precise without information overload

# Volcano Plot

## Description

The volcano plot is the most widely used visualization in metabolomics differential analysis. It simultaneously displays two key dimensions: the x-axis shows log2 fold change (log2FC), reflecting the magnitude of concentration differences between groups; the y-axis shows -log10 adjusted p-value, reflecting statistical confidence. The plot is named for its characteristic volcano-like shape.

## How to Read

- **Upper right (red dots)**: Significantly up-regulated metabolites with higher concentration in the experimental group (FC > threshold AND p < threshold)
- **Upper left (blue dots)**: Significantly down-regulated metabolites with lower concentration in the experimental group
- **Central grey area**: Non-significant metabolites with insufficient fold change or statistical power
- Labeled compound names indicate metabolites successfully annotated through spectral library matching
- Vertical dashed lines mark the FC threshold (typically ±1); horizontal dashed line marks the p-value threshold (typically 0.05)

## Important Notes

- Both p-value and FC thresholds are adjustable; set them based on biological context
- Labels show only high-confidence annotations — unlabeled dots are not necessarily unimportant
- If most points cluster in the grey zone, the true biological differences may be small, or sample size may be insufficient for adequate statistical power
- P-values should be corrected using the BH method (FDR) to control false positives from multiple testing

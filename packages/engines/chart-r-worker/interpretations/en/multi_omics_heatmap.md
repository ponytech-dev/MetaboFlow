# Multi-omics Integration Heatmap

## Description

The multi-omics integration heatmap displays metabolomics data alongside transcriptomics (gene expression) or proteomics data within a single heatmap framework, arranged in blocks by shared pathways (e.g., TCA cycle, glycolysis). ComplexHeatmap's row split feature partitions different omics layers into distinct regions; pathway annotation bars connect across layers to reveal coordinated regulatory patterns across multiple omics levels.

## How to Read

- **Row blocks (pathway grouping)**: Each pathway occupies one row block containing the metabolites, genes, or proteins from that pathway
- **Color consistency**: All omics layers use a unified color gradient (red = high, blue = low) to facilitate cross-layer comparison
- **Columns (samples)**: Column arrangement is consistent across layers, enabling identification of coordinated changes in the same sample across omics levels
- **Pathway annotations (left side)**: Color bars annotate pathway names and omics layer identity, helping identify data sources
- **Coordinated patterns**: If a pathway's metabolites and related genes are both red in the same sample group, that pathway is up-regulated at both the transcriptional and metabolic levels — providing strong, multi-layer systemic evidence

## Important Notes

- Multi-omics integration requires matched samples (the same individual providing data for each omics layer)
- Different omics layers may use different normalization approaches — direct cross-layer color depth comparisons require caution
- Readability decreases when too many rows are displayed (>50 rows) — show only core metabolites/genes per pathway
- This figure is a central plot in systems biology research, effectively presenting multi-omics co-regulation evidence

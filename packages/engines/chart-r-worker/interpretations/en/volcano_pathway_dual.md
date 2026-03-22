# Volcano + Pathway Enrichment Dual-Panel

## Description

The differential metabolite and pathway enrichment dual-panel consists of two side-by-side panels: the left shows the volcano plot (global view of differential metabolites), and the right shows a pathway enrichment bar chart or bubble plot (functional annotation of those differential metabolites). Both panels use a coordinated color scheme to construct a complete narrative of "differential discovery + functional interpretation" — one of the most common dual-panel main figure formats in Nature/Science series journals.

## How to Read

- **Left panel (volcano plot)**: Identifies which metabolites are significantly up- or down-regulated, providing the input basis for the right panel's enrichment
- **Right panel (pathway enrichment)**: Shows which metabolic pathways are primarily represented by these differential metabolites, answering "which functions are affected?"
- **Color coordination**: When both panels use the same color encoding (e.g., up-regulated = red), readers can trace volcano plot dots back to the corresponding pathway members in the right panel
- **Pathway-metabolite linkage**: While reading both panels, consider: which significant dots in the volcano plot are members of the most enriched pathways in the right panel?
- **Figure legend**: Must clearly state that the threshold parameters in the left panel (FC and p-value cutoffs) define the input for the enrichment analysis in the right panel

## Important Notes

- Panel size ratios should be balanced; the volcano plot is typically slightly larger to show more data point information
- The pathway enrichment panel typically shows the Top 10–20 pathways — showing too many causes information overload
- If enrichment results show no significant pathways (none with p<0.05), re-examine the differential metabolite list and annotation completeness
- This dual-panel format is standard for main figures submitted to high-impact journals — ensure publication quality (font size, resolution, etc.)

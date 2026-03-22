# Pathway Enrichment Bubble Plot

## Description

The pathway enrichment bubble plot encodes three dimensions of information simultaneously: bubble position (or y-axis rank) reflects pathway name or enrichment score; bubble size corresponds to the number of differential metabolites hitting that pathway (count); bubble color reflects p-value or FDR. This provides a more intuitive view of the combined relationship between pathway coverage and statistical significance.

## How to Read

- **Bubble size**: Larger bubbles indicate more differential metabolites detected in that pathway — broader coverage
- **Bubble color**: Deeper/redder color indicates smaller p-value (stronger enrichment); lighter color indicates higher FDR
- **Position (enrichment ratio/GeneRatio)**: The x-axis typically shows hit count / total pathway members, reflecting relative enrichment intensity
- **Dual selection criterion**: Pathways with both large bubbles and deep color have the strongest combined biological significance

## Important Notes

- The bubble plot conveys one more dimension than a bar chart, better distinguishing between "many hits but weak p-value" vs. "few hits but highly significant p-value"
- If all bubbles appear light (none statistically significant), too few annotated metabolites may be entering the analysis — revisit upstream steps
- The y-axis pathway order is typically sorted by p-value, but pathways can also be grouped by metabolic category (e.g., lipid metabolism, amino acid metabolism)
- Complement bubble plot findings with KEGG pathway map overlays to understand where differential metabolites fall within specific pathways

# Pathway Enrichment Bar Chart

## Description

The pathway enrichment bar chart displays the enrichment results of differential metabolites across KEGG/HMDB metabolic pathways. Each horizontal bar represents one pathway; bar length corresponds to the enrichment ratio or -log10(p-value); color intensity encodes p-value significance. Pathways are sorted in ascending order of p-value, with the most significant pathways at the top.

## How to Read

- **Bar length**: Longer bars indicate stronger enrichment of differential metabolites in that pathway
- **Color encoding**: Deeper colors (typically darker red) indicate smaller p-values and more credible enrichment
- **Pathway names**: KEGG/HMDB pathway names are labeled on the left or right side
- **Hit/total count**: Shows the number of differential metabolites vs. total pathway members; a higher ratio indicates better pathway coverage
- **Top pathways**: The top 5–10 most significant pathways are usually the most relevant biological modules for further investigation

## Important Notes

- Enrichment results are highly dependent on the input differential metabolite list — different thresholds can substantially alter results
- When metabolite annotation coverage is low (<30%), pathway enrichment results have limited interpretive value
- Large pathways (e.g., amino acid metabolism) have more members, increasing the chance of random hits — statistical significance does not always imply true biological relevance
- Cross-validate enrichment findings using the pathway bubble chart

# Annotated Heatmap with ClassyFire Chemical Classification

## Description

The ClassyFire annotated heatmap adds chemical superclass color bars (e.g., amino acids, lipids, organic acids) alongside each row of the standard clustered heatmap. This reveals relationships between chemical class membership and expression clustering patterns. Different superclasses use distinct colors, enabling readers to quickly identify which chemical classes are collectively up- or down-regulated in a given group.

## How to Read

- **Row annotation bars**: Colored bars next to each row (metabolite) indicate its ClassyFire chemical superclass
- **Chemical class clustering**: When annotation bars of the same color concentrate in a particular region of the heatmap, that chemical class shares similar expression patterns
- **Mixed regions**: Regions with interleaved colors indicate that the cluster contains multiple chemical classes with more complex patterns
- **Top column annotations**: Column annotation bars mark sample groups — combining row chemical annotations with column groupings reveals "which chemical class is elevated in which sample group"
- **Heatmap color gradient**: Same as standard heatmaps — red indicates high abundance, blue indicates low abundance

## Important Notes

- ClassyFire annotations depend on accurate molecular structures (SMILES) — incorrect structural annotations propagate to incorrect chemical classifications
- Too many unannotated features ("Unknown" superclass) dilutes the interpretive value of this plot
- Heatmap clustering is driven by expression patterns; chemical class clustering is an emergent natural pattern, not forced by classification
- This plot is well-suited to present an "integrated view of metabolite chemical diversity and differential regulation" and commonly appears in Nature/Science main figures

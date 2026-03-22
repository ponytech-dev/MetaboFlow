# ChemRICH Chemical Enrichment Plot

## Description

The ChemRICH enrichment plot performs enrichment analysis based on chemical similarity (rather than KEGG pathways), clustering differential metabolites by chemical structure. Each bubble represents one chemical structure cluster; bubble area reflects the number of differential metabolites in that cluster; bubble color reflects the proportion of up- vs. down-regulated metabolites (red-biased = overall up-regulated, blue-biased = overall down-regulated); p-values are calculated by the Kolmogorov-Smirnov (KS) test.

## How to Read

- **Bubble size**: Larger bubbles indicate more differential metabolites in that chemical structure cluster
- **Bubble color (red-blue gradient)**: Red-biased bubbles indicate the cluster shifts overall toward up-regulation; blue-biased indicates overall down-regulation; neutral color indicates no clear directional preference
- **Bubble position**: Typically sorted by chemical superclass or p-value; chemically similar clusters are positioned adjacently
- **Significant bubbles (KS p<0.05)**: Marked with bold borders or asterisks, indicating that chemical class shows statistically significant overall differential regulation
- **Bubble labels**: Annotate chemical superclass or structural category names (e.g., fatty acids, amino acids)

## Important Notes

- ChemRICH does not depend on the KEGG database — it is well-suited for metabolites with low KEGG coverage (e.g., microbial metabolites, industrial chemicals)
- Requires SMILES or InChIKey for chemical similarity clustering — annotation quality directly determines result quality
- Complements KEGG pathway enrichment: ChemRICH focuses on chemical structural categories; KEGG focuses on biochemical functions
- The KS test is sensitive with large samples — small differences within large clusters may appear statistically significant

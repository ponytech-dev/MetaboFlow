# KEGG Pathway Map Overlay

## Description

The KEGG pathway map overlay colors metabolite nodes on the official KEGG metabolic pathway diagram: up-regulated metabolite nodes become red/orange, down-regulated nodes become blue/green, and undetected or non-differential metabolites remain grey. This provides a panoramic view of perturbed metabolic pathways, showing which reaction nodes are activated or inhibited.

## How to Read

- **Red/orange nodes**: Up-regulated metabolites at that position in the pathway, suggesting increased metabolic flux through that step
- **Blue/green nodes**: Down-regulated metabolites, suggesting reduced flux or pathway inhibition
- **Consecutive colored blocks**: Adjacent nodes that are all colored indicate coordinated regulation across multiple steps of that pathway
- **Isolated colored nodes**: Only a single node changing color may indicate that metabolite participates in multiple pathways — interpret alongside other pathway visualizations
- **Uncolored (grey) areas**: Either not detected as differential or not annotated — do not infer that those metabolites are unchanged

## Important Notes

- KEGG pathway overlay requires accurate KEGG Compound IDs — annotation quality directly determines result accuracy
- The KEGG pathway map is a static framework and does not reflect actual metabolic flux (which requires stable isotope tracing)
- The same metabolite may appear in multiple pathways — avoid over-interpreting any single pathway map in isolation
- This plot depends on the pathview or ggkegg package and requires network access to the KEGG API

# Enhanced Volcano Plot with Annotation Layer

## Description

The enhanced annotated volcano plot adds a Schymanski confidence level coloring layer on top of the standard volcano plot. Point color encodes not just up/down-regulation direction but also annotation confidence (Level 1: confirmed with reference standard; Level 2: spectral library match; Level 3: structural inference). Compound labels use ggrepel to prevent overlap and are only shown for annotated significant metabolites.

## How to Read

- **Dual color encoding**: Color simultaneously conveys differential direction (red = up-regulated, blue = down-regulated) and annotation confidence level (distinguished by shape or color shade)
- **Level 1 (solid border)**: Confirmed with authentic reference standard — highest confidence annotation
- **Level 2 (dashed border)**: Spectral library match — high-confidence candidate compound
- **Level 3 (grey dots)**: Structural inference — supported by only partial evidence
- **Compound labels**: Only Level 1–2 significantly differential metabolites are labeled to avoid information overload
- **Legend**: Must explain both the directional color coding and the confidence level encoding simultaneously

## Important Notes

- Unannotated features (no confidence level) are not necessarily unimportant — they may represent novel compounds
- Level 3 and below annotations should be described as "putative" in manuscripts and should not serve as primary research conclusions
- Very few Level 1 annotations in the plot suggests limited database coverage — consider expanding the annotation database
- This plot is suitable as a main figure panel providing an integrated overview of differential metabolites and annotation quality

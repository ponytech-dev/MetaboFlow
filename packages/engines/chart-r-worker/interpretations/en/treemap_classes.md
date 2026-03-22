# Treemap by Chemical Class

## Description

The chemical class treemap visualizes the distribution of annotated metabolites by chemical class using nested rectangles proportional in area. The hierarchy progresses from outermost to innermost: superclass → class → subclass. Each rectangle's area is proportional to the number of annotated features in that category; colors distinguish different superclasses; embedded labels show category names and feature counts.

## How to Read

- **Large rectangles**: Larger area indicates more annotated metabolites in that chemical category — these represent the dominant chemical composition of the sample's metabolic profile
- **Nested hierarchy**: Successive layers from superclass to subclass reveal the hierarchical structure of metabolite chemical classification
- **Color partitioning**: Different-colored large blocks correspond to distinct superclasses (e.g., lipids, amino acids, organic acids) at a glance
- **Small rectangles**: Inner rectangles represent subclasses; a notably large inner rectangle indicates that particular subclass is especially well-represented in the detection
- **Overall proportions**: The treemap reflects the distribution of annotated metabolites across chemical space — compare to the expected chemical class composition for that biological system

## Important Notes

- Treemap areas reflect only the count of annotated metabolites, not absolute concentration or abundance
- Annotation bias (certain superclasses being more easily matched by spectral libraries) can distort the treemap — avoid over-interpreting proportions
- Unannotated features are excluded from the treemap — low annotation coverage means the treemap cannot represent the true chemical composition of the metabolome
- This figure is appropriate for the Methods section to describe the chemical diversity of annotated metabolites in the study

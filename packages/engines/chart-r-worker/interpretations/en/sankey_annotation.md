# Sankey / Alluvial Annotation Quality Diagram

## Description

The annotation quality Sankey diagram visualizes the flow of features through each stage of the metabolomics annotation pipeline: from raw detected features → MS1 quality filtering → database search hits → Schymanski confidence level classification. Each flow width is proportional to the number of features passing through that node, intuitively showing the "funnel" efficiency of each annotation stage and the final distribution of annotations by confidence level.

## How to Read

- **Nodes (wide rectangles)**: Each processing stage; node width represents the total number of features at that stage
- **Flows (connecting bands)**: Features transitioning from one node to the next; band width represents the count
- **Branching flows**: At annotation level nodes, flows branch toward multiple levels (Level 1/2/3, etc.); band widths reflect the proportion annotated at each level
- **Narrowing funnel**: Feature counts decreasing from left to right is expected; faster narrowing indicates lower hit rate or stricter filtering at that step
- **Color coding**: Different colors can distinguish chemical classes or annotation source databases (e.g., HMDB, MassBank)

## Important Notes

- The Sankey diagram is a workflow quality summary — it does not display information about individual metabolites
- When many features fail to match any database, investigate whether the database coverage and mass tolerance settings are appropriate
- This figure is commonly used in the Supplementary section of methods papers to demonstrate annotation workflow systematicity
- The proportion of annotations at each confidence level serves as a quality metric for comparing different annotation approaches

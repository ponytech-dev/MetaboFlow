# Annotation Candidate Waterfall Chart

## Description

The annotation candidate waterfall chart displays candidate compound annotations ranked from highest to lowest by composite score (allscore). Each horizontal bar represents one candidate hit; bar length corresponds to the total score; color encodes the Schymanski confidence level (Level 1–5). The cascading waterfall shape intuitively shows score distribution, enabling rapid identification of high-confidence annotations and separation of high- from low-quality candidates.

## How to Read

- **Bar length (score)**: Longer bars indicate higher scores, integrating multiple factors including MS1 accurate mass, isotope distribution, MS2 spectral matching, and RT deviation
- **Color (Schymanski level)**: Different colors distinguish Level 1 (highest, confirmed with reference standard) through Level 5 (lowest, molecular formula inference only)
- **Waterfall shape**: The position where scores drop sharply (the "elbow") helps identify a reasonable score cutoff threshold
- **Multiple candidates per feature**: If a feature has multiple candidates, multiple adjacent bars appear — the top candidate is the best annotation
- **Compound name labels**: Typically shown on or beside bars; only top candidates or high-confidence annotations are labeled

## Important Notes

- The scoring system uses MetaboFlow's custom weights — absolute scores are not comparable across different experiments or database configurations
- Total score alone cannot confirm an annotation — verify that each component score (MS1, isotope, MS2) is individually reasonable
- Level 4–5 candidates are exploratory only and should not serve as the basis for annotation claims in manuscripts
- This chart is typically used as a quality overview of the annotation workflow, used alongside the Chemical Identity Card (A13)

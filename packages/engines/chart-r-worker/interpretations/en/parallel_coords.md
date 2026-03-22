# Parallel Coordinates Plot

## Description

The parallel coordinates plot visualizes multi-dimensional scoring of candidate annotation compounds. Each candidate compound is represented as one line passing through multiple parallel axes (e.g., MS1 accurate mass score, isotope score, MS2 similarity score, RT score, adduct score), with each axis representing one scoring dimension (0–1 normalized). The vertical position of each line on each axis reflects the candidate's score in that dimension, helping identify candidates with uniformly high scores.

## How to Read

- **Line height on each axis**: Higher positions indicate higher scores in that dimension; candidates with lines consistently near the top across all axes have the best overall annotation quality
- **Color coding**: Different colors distinguish individual candidate compounds, or color can encode the Schymanski confidence level
- **Crossing patterns**: Many line crossings between two specific axes indicate a negative correlation between those two scoring dimensions (e.g., good MS1 but poor MS2)
- **Single-dimension bottleneck**: If a candidate scores high on all dimensions but has one notably low axis, that dimension is the weak point of its annotation
- **Clustered lines**: Candidates with similar scores form nearly parallel line bundles, indicating those candidates are difficult to distinguish from each other

## Important Notes

- Axis ordering affects crossing frequency — arrange correlated dimensions adjacently for cleaner visualization
- When the number of candidates exceeds 20, the plot becomes cluttered — display only the top 10–15 candidates
- Dimensions have different weights and thresholds — do not judge candidate quality solely by visual line height; consider actual threshold values for each dimension
- This plot is better suited to interactive visualization (e.g., Shiny or plotly); static versions have limited readability

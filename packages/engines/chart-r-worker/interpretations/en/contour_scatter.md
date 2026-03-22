# Contour Scatter Plot

## Description

The contour scatter plot overlays feature density contours onto the m/z-RT two-dimensional plane, while simultaneously highlighting annotation hit regions (positions of identified compounds). Contour lines are derived from kernel density estimation (KDE), connecting regions of equal density; color depth reflects the density gradient. Annotation hits are overlaid with special markers (e.g., large dots or stars), revealing in which m/z-RT regions annotations are primarily concentrated.

## How to Read

- **Dense contour regions**: m/z-RT zones with the highest feature density — correspond to chemical space with the best detection efficiency
- **Annotation hit distribution (highlighted points)**: Annotation hits concentrated in high-density contour zones indicate good coverage of the major detected features; sparsely distributed annotation points indicate many detected features remain unannotated
- **Contour voids**: Low-density m/z-RT blank zones indicating low instrument detection efficiency in that chemical space
- **Annotation blank zones (high density but no annotations)**: Suggests many detected features in that region have no database matches — possibly novel compounds or insufficient database coverage

## Important Notes

- Contour smoothness is controlled by the bandwidth parameter — too large a bandwidth masks true density peak structures
- This plot does not distinguish true metabolites from noise features — plot it on a filtered feature set for meaningful interpretation
- m/z ranges and sensitivity differ across instruments — exercise caution when comparing across platforms
- Draw separate contour scatter plots for positive and negative ion modes, as coverage regions differ between modes

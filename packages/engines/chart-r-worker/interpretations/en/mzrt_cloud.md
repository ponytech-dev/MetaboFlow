# Feature Cloud Plot (m/z-RT Scatter Plot)

## Description

The feature cloud plot displays all globally detected features in a two-dimensional space, with the x-axis representing retention time (RT, minutes) and the y-axis representing mass-to-charge ratio (m/z). Each point represents one detected feature; color or size encodes maximum or mean intensity. This plot provides a bird's-eye view of the entire metabolomics dataset.

## How to Read

- **Feature density distribution**: Dense regions (typically RT 2–15 min) correspond to retention time windows with good chromatographic separation
- **Point size/color**: Larger or brighter points represent higher-abundance features, typically major metabolites
- **Sparse regions**: The high m/z region (>1000 Da) has fewer features; m/z < 100 is dominated by solvent ions
- **Total feature count**: The number of points reflects the scale of the analysis; positive ion mode typically yields 2,000–10,000 features

## Important Notes

- The feature cloud does not distinguish true metabolites from noise features — biological interpretation requires post-filtering
- Clusters of features with the same RT but different m/z values may represent adducts or isotope peaks of the same compound
- Dense feature clusters in the m/z 500–900 Da range are commonly associated with phospholipid metabolites
- Comparing feature clouds across batches is a quick way to detect RT drift or mass axis shift between acquisitions

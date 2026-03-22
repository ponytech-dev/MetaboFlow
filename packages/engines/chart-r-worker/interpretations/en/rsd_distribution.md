# RSD Distribution Plot (Relative Standard Deviation)

## Description

The RSD distribution plot displays the distribution of relative standard deviations (RSD% = SD/Mean×100) calculated for all features across QC samples. It is typically shown as a histogram or cumulative frequency distribution curve, with 20% and 30% quality threshold lines annotated. RSD reflects the analytical reproducibility for each feature.

## How to Read

- **Distribution peak position**: Most features concentrating at RSD 5–20% indicates excellent method reproducibility
- **20% threshold line**: Features to the left of this line are high-quality; metabolomics studies typically require ≥80% of features to have RSD<20%
- **Long tail**: A pronounced right tail (many high-RSD features) indicates numerous unstable features in the data that should be filtered
- **Bimodal distribution**: A double peak may reflect two populations — high-abundance features (low RSD) and low-abundance features (high RSD) — with different reproducibility profiles
- **Cumulative curve slope**: A steeper slope indicates features are more tightly clustered at low RSD values

## Important Notes

- RSD is calculated from QC samples only; results are unreliable when fewer than 5 QC samples are available
- RSD distributions typically differ between positive and negative ion modes — assess each separately
- High-RSD features are not necessarily biologically irrelevant, but their statistical analysis results are less credible and are typically filtered before differential analysis
- After batch correction, RSD values should decrease substantially — compare pre- and post-correction distributions to evaluate correction effectiveness

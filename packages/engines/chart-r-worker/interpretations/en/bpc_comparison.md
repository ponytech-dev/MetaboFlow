# BPC Chromatogram (Base Peak Chromatogram Comparison)

## Description

The base peak chromatogram (BPC) displays the intensity of the most abundant ion (base peak) at each mass spectrometer scan as a function of retention time. Compared to TIC, BPC has a higher signal-to-noise ratio and clearer peak shapes, making it the preferred tool for assessing chromatographic separation quality and peak shape. Multi-sample overlays quickly reveal peak shape anomalies or retention time drift.

## How to Read

- **Peak symmetry**: Ideal chromatographic peaks should approximate a Gaussian shape, with an asymmetry factor (tailing factor) between 0.8 and 1.5
- **Resolution**: Adjacent peaks should have a clear valley between them; severe co-elution compromises quantitative accuracy
- **Retention time reproducibility**: Peak apex positions for the same compound should deviate by less than 0.05 min across all samples
- **Signal intensity differences**: Peak height variation across samples for the same compound reflects concentration or injection volume differences

## Important Notes

- The most intense peaks in the BPC are not necessarily metabolites of interest — they may be matrix components or solvent peaks
- Large peaks eluting early (before 1 min) are typically solvent front or highly polar matrix interferences, not metabolite signals
- Compare with TIC: if TIC areas differ substantially but BPC is consistent, low-abundance features likely drive the batch differences
- Broadened or fronting peak shapes indicate potential column degradation or flow rate issues requiring investigation

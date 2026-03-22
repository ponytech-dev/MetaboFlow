# Extracted Ion Chromatogram (EIC)

## Description

The extracted ion chromatogram (EIC) displays the intensity of ions within a specified m/z window (target mass ± ppm tolerance) as a function of retention time, used to verify the detection of specific compounds. The plot annotates detected peaks and their integration boundaries; multiple samples can be overlaid for comparison.

## How to Read

- **Single clean peak**: A single symmetric peak at the expected retention time indicates reliable detection of that compound
- **Peak area**: Proportional to compound concentration; between-group peak area differences reflect quantitative differences
- **Multiple peaks**: Multiple peaks at the same m/z but different retention times may indicate isomers or adduct ions
- **Annotated RT and m/z**: Verify whether detected peaks match theoretical values (RT deviation <0.05 min, mass error <5 ppm)

## Important Notes

- The ppm window setting critically affects results: too narrow may miss the peak; too wide may introduce interfering peaks
- Absence of a peak at the target RT may indicate the compound is below the detection limit or has undergone RT drift
- Review EIC in both positive and negative ion modes for comprehensive detection assessment
- EIC plots serve as important supporting evidence for MS2 annotation verification and should be cross-referenced with mirror spectra

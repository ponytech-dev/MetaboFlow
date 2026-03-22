# TIC Chromatogram (Total Ion Chromatogram Overlay)

## Description

The TIC chromatogram displays the total intensity of all detected ions at each mass spectrometer scan as a function of retention time. Multiple sample TIC traces are overlaid to rapidly assess instrument signal stability, chromatographic reproducibility, and overall sample-to-sample consistency. Each line represents one sample; QC samples are typically highlighted in a distinct color.

## How to Read

- **Peak shape consistency**: All sample TIC traces should be highly similar in shape, with characteristic peaks aligned in position and relative height
- **Signal intensity**: If total peak areas differ by more than 30% across samples, this suggests dilution errors or inconsistent injection volumes
- **QC sample overlap**: Multiple QC sample traces should nearly perfectly overlap; divergence indicates instrument instability
- **Baseline drift**: A rising or falling baseline over time may indicate solvent contamination or column degradation

## Important Notes

- TIC is used for quality control only, not for quantification
- A single sample with significantly elevated TIC area may indicate injection overload or matrix effects; a very low TIC may indicate injection failure
- Retention time shifts greater than 0.05 min warrant attention to chromatographic stability and may require RT correction
- If an entire batch shows collectively lower signal, investigate the injection sequence for batch effects

# MS2 Mirror Plot (Fragment Spectrum Comparison)

## Description

The MS2 mirror plot displays the experimental MS2 fragment spectrum (top) and the reference library spectrum (bottom) in a symmetric layout. The x-axis shows m/z and the y-axis shows relative intensity (0–100%). Matching fragment ions are typically highlighted in color, and the cosine similarity score is displayed prominently.

## How to Read

- **Cosine similarity score**: Ranges from 0 to 1; scores >0.7 are generally considered credible matches, and >0.85 indicates high-confidence annotation
- **Matched fragments (colored)**: Peaks in both experimental and reference spectra with m/z within the tolerance window
- **Unmatched fragments (grey)**: Peaks in the experimental spectrum without a counterpart in the reference, possibly from noise or adducts
- **Intensity distribution**: If the relative intensity ratios of major fragments closely match the reference, annotation confidence increases
- **Precursor ion annotation**: The precursor m/z is labeled at the top; verify it matches the expected molecular weight of the target compound

## Important Notes

- Cosine scores below 0.5 should not be used as the basis for annotation
- MS2 spectra can vary across instruments and collision energies — always integrate with accurate MS1 mass measurements
- Library matching reaches Schymanski confidence level 2–3 at most; definitive confirmation requires authentic reference standards
- Treat matches with fewer than 3 matched fragments cautiously, even if the score appears acceptable

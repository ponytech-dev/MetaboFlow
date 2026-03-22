# Isotope Pattern Verification Plot

## Description

The isotope pattern verification plot compares the experimental isotope distribution (M, M+1, M+2, M+3) of each candidate compound against the theoretical values calculated from the molecular formula, using paired bar charts. Each isotope peak is shown as a pair of bars — experimental (blue) and theoretical (orange) — with mass accuracy (ppm error) and isotope pattern match score annotated.

## How to Read

- **Experimental vs. theoretical bar height ratios**: Closer matching ratios indicate better agreement between the observed isotope distribution and the proposed molecular formula
- **M+1/M ratio**: Reflects the number of carbon atoms (each C contributes ~1.1% M+1 intensity), enabling a quick estimate of carbon count in the molecule
- **M+2/M ratio**: Elevated M+2 peaks indicate heteroatoms such as S, Cl, or Br — useful as a rapid screen for halogenated or sulfur-containing compounds
- **ppm error annotation**: Accurate mass error for the M+0 peak; <5 ppm is acceptable; <2 ppm is the standard for high-resolution instruments
- **Isotope score**: Calculated from the combined matching of multiple isotope peaks; >0.8 strongly supports the proposed molecular formula

## Important Notes

- For low-abundance features, M+1 and M+2 peaks have poor signal-to-noise ratios, making isotope distribution unreliable and limiting the value of this verification
- Elevated M+2 is not always from halogens — it can also arise from co-eluting impurity peaks overlapping at the same RT
- Isotope pattern verification is most meaningful with high-resolution mass spectrometry (HRMS); do not emphasize this evidence for low-resolution data
- This plot is an important component of the Chemical Identity Card (A13)

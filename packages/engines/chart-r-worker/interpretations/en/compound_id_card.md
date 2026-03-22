# Chemical Identity Card

## Description

The Chemical Identity Card is a multi-panel composite display of annotation evidence for a single compound. It typically contains 4–6 sub-panels: (1) molecular structure (SMILES rendering), (2) MS2 mirror comparison plot, (3) isotope pattern verification plot, (4) EIC extracted ion chromatogram, and (5) a summary table of key annotation metrics (confidence level, accurate mass error, cosine similarity, RT deviation). All evidence converges in one figure for the most comprehensive annotation verification view.

## How to Read

- **Molecular structure panel**: Shows the 2D structure of the candidate compound, visually presenting functional groups and backbone
- **MS2 mirror plot**: Validates the fragmentation pattern; cosine similarity should be >0.7
- **Isotope verification plot**: Confirms the molecular formula; M+1/M+2 ratios should match theoretical values
- **EIC plot**: Confirms a clean, symmetric chromatographic peak at the target RT
- **Summary metrics**: Schymanski level, accurate mass error (ppm), RT deviation (min), and MS2 similarity score at a glance
- **Integrated judgment**: High-confidence annotation requires all evidence to be satisfactory; insufficient evidence in any component reduces the confidence level or warrants a "tentative" label

## Important Notes

- The Chemical Identity Card is the most persuasive annotation supporting material for supplementary sections of a manuscript
- It requires raw mzML data (for EIC), MS2 spectral data, and RDKit/rcdk for structure rendering
- One identity card applies to one candidate compound only — it is not used to compare multiple candidates side-by-side
- If molecular structure rendering fails, InChI Key or SMILES string can substitute

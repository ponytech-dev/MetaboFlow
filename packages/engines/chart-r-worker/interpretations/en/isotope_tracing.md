# Stable Isotope Tracing Flux Plot (Isotopologue Distribution)

## Description

The stable isotope tracing flux plot (isotopologue distribution plot) displays the distribution of each isotopologue of target metabolites from labeling experiments (e.g., ¹³C-glucose, ¹³C-glutamine): M+0 (unlabeled), M+1 (one ¹³C), M+2 (two ¹³C), etc. Relative abundances are shown as stacked bar charts, reflecting the carbon skeleton origin and metabolic flux direction of each metabolite.

## How to Read

- **M+0 proportion**: The fraction of unlabeled molecules; a lower M+0 proportion indicates more synthesis of that metabolite from the labeled substrate
- **N value in M+N**: Indicates the number of labeled carbon atoms incorporated; N reflects how many metabolic steps were required to integrate that carbon skeleton into the target metabolite
- **Isotopologue distribution comparison across groups**: Different isotopologue patterns under different conditions indicate differences in metabolic pathway activity or flux rates
- **Color coding**: Each M+N is filled with a distinct color; the 100% stacked height reflects the relative proportion of each isotopologue within that group
- **Time series**: If multiple time points are included, increasing label incorporation over time reflects flux rates

## Important Notes

- Natural abundance correction is a mandatory step — uncorrected data will overestimate M+1/M+2 proportions
- An increase in M+2 only (not M+1) may reflect acetyl group transfer (e.g., labeling derived from acetyl-CoA)
- This analysis requires a specifically designed stable isotope tracing experiment — it cannot be derived from conventional untargeted metabolomics data
- The flux plot must be interpreted alongside a metabolic pathway diagram to confirm the specific direction of carbon skeleton flow

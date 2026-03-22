# Ridge Plot (Joy Plot)

## Description

The ridge plot (also called Joy Plot) overlays abundance distributions for multiple groups or time points, with each group represented by a kernel density curve arranged from top to bottom with slight overlap, creating the characteristic ridge visual effect. Compared to multiple side-by-side boxplots, the ridge plot more intuitively reveals distributional shape, peak position shifts, and multimodal distribution patterns.

## How to Read

- **Peak position**: The highest point of each ridge corresponds to the most common (modal) abundance value for that group; horizontal shifts in peak position from top to bottom reflect mean differences between groups
- **Distribution width**: Wide and flat ridges indicate high within-group variability; narrow and sharp ridges indicate high within-group consistency
- **Bimodal or multimodal peaks**: A bimodal distribution in one group suggests the possible presence of two sub-populations (e.g., responders and non-responders)
- **Color fill**: Groups are typically filled with gradient or distinct colors to enhance visual differentiation
- **Tails**: The direction and length of distribution tails indicate the presence of a few individuals with extreme high or low concentrations

## Important Notes

- Ridge plots work best when there are ≥3 groups and distribution shape matters; for only 2 groups, a boxplot is more concise
- Kernel density bandwidth affects ridge shape — too small creates jagged edges; too large over-smooths the distribution
- With small sample sizes (n<10), kernel density estimation is unreliable — use violin plots with overlaid data points instead
- This plot does not directly display statistical significance — combine with statistical test results

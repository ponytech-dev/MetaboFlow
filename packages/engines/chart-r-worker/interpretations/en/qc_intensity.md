# Sample QC Intensity Boxplot

## Description

The sample QC intensity boxplot displays the total ion intensity or feature count distribution for each sample as a series of boxplots arranged in injection order. QC samples (pooled quality control) are highlighted in a distinct color to track instrument signal stability across the entire batch and quickly identify batch effects or anomalous samples.

## How to Read

- **Box height**: Reflects the variability of feature intensities within that sample; a taller box indicates higher within-sample heterogeneity
- **Overall trend**: A monotonic increase or decrease along injection order indicates instrument signal drift
- **QC sample boxes (highlighted)**: QC boxes should maintain consistent position and height throughout the batch — they serve as the baseline for batch effect assessment
- **Individual outlier samples**: A sample box significantly higher or lower than others indicates an injection volume anomaly or severe matrix effects
- **Inter-batch jumps**: When comparing multiple batches, systematic jumps between batches require batch correction

## Important Notes

- Samples with total intensity deviating more than 30% from the median should be flagged and evaluated before inclusion in downstream analysis
- Target QC sample RSD < 30%; values above this threshold indicate insufficient instrument reproducibility
- Use this plot together with the RSD distribution plot for a comprehensive data quality assessment
- Different sample matrices (e.g., serum vs. urine) inherently differ in intensity distributions and should not be directly compared

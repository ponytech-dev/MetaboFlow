# ROC Curve (Receiver Operating Characteristic Curve)

## Description

The ROC curve evaluates the diagnostic ability of a metabolite or combination of metabolites as a biomarker. The x-axis shows the false positive rate (1-specificity) and the y-axis shows the true positive rate (sensitivity). Greater deviation of the curve toward the upper left corner indicates stronger classification ability. AUC (area under the curve) is the composite diagnostic score; multiple metabolites' ROC curves are shown together to facilitate comparison and selection of the best biomarker.

## How to Read

- **AUC value**: AUC = 0.5 is equivalent to random guessing (diagonal line); AUC > 0.7 is acceptable diagnostic ability; AUC > 0.9 is excellent diagnostic ability
- **Curve shape**: The closer the curve is to the upper left corner (coordinates 0,1), the stronger the diagnostic ability
- **Optimal operating point (maximum Youden's Index)**: The point maximizing sensitivity + specificity — the optimal classification threshold
- **95% CI shading**: Non-overlapping confidence intervals between curves indicate statistically significant differences in diagnostic ability
- **Diagonal reference line**: Represents a random classifier with no diagnostic ability (AUC = 0.5)

## Important Notes

- ROC analysis applies only to binary classification outcomes (case/control) — it is not appropriate for multi-group designs
- With small sample sizes, AUC estimates are unstable — always report 95% confidence intervals and conduct statistical tests (e.g., DeLong test)
- Internal validation AUC (same dataset) carries overfitting risk — independent validation or cross-validation is strongly recommended
- Single-metabolite AUC is typically lower than multi-metabolite panels, but panels require attention to multicollinearity

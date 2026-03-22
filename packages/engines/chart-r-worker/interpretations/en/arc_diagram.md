# Arc Diagram

## Description

The arc diagram displays cross-contrast relationships in the differential direction of features across multiple comparisons. Nodes (features) are arranged along a horizontal axis; arcs connecting two nodes indicate that those two features are simultaneously significant in a contrast with synergistic or antagonistic relationships. Arc color distinguishes co-up-regulated pairs (red arc), co-down-regulated pairs (blue arc), or opposing regulation (grey arc); arc thickness reflects association strength or frequency of co-occurrence.

## How to Read

- **Arc colors**: Red arcs connect metabolite pairs that are both up-regulated across multiple contrasts; blue connects pairs both down-regulated; grey connects antagonistic pairs (one up, one down)
- **High-degree nodes (hubs)**: Nodes connected to many arcs are core metabolites that are significantly differential across multiple contrasts
- **Dense arc regions**: Areas with many features and arcs suggest those metabolites participate in the same metabolic pathway or share common regulatory control
- **Cross-contrast consistency**: Dark arcs spanning multiple contrasts indicate the relationship between that metabolite pair is stable across multiple conditions
- **Isolated nodes**: Nodes with no arcs are significant in only a single contrast

## Important Notes

- Arc diagrams are suited to displaying cross-contrast co-differential patterns across 3–6 comparisons
- Too many nodes (>50) creates a tangled arc diagram — display only Top features with the highest VIP or FC values
- Arc connections are based on statistical co-significance, not direct biochemical interactions
- This plot has low readability for non-specialist audiences — provide a detailed interpretation guide in the figure legend

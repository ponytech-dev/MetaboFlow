# Molecular Network

## Description

The molecular network constructs a node-edge network based on cosine similarity of MS2 fragment spectra. Each node represents one detected feature; an edge connects two nodes when their MS2 spectral cosine similarity exceeds a threshold (typically >0.7). Structurally similar compounds naturally cluster into groups, and node color can encode chemical classification, log2FC, or annotation confidence — providing structural clues for unannotated metabolites.

## How to Read

- **Clusters**: Regions of densely connected nodes represent families of compounds with similar fragmentation patterns (typically the same chemical class)
- **Edge thickness/color**: Reflects the cosine similarity between two nodes — thicker/darker edges indicate higher similarity
- **Isolated nodes**: Nodes with no edges indicate features whose MS2 does not resemble any other feature — possibly unique structures or poor MS2 quality
- **Node color (log2FC)**: Red nodes are up-regulated in the experimental group; blue nodes are down-regulated; grey nodes show no significant difference
- **Annotated nodes (labeled)**: Nodes with compound name labels serve as structural reference anchors for the clusters they belong to

## Important Notes

- Molecular networking requires sufficient MS2 data quality — low MS2 coverage yields sparse networks with limited interpretive value
- The cosine similarity threshold controls network density: too low leads to over-connection; too high leads to an overly sparse network
- Unannotated nodes within a cluster can be structurally inferred based on neighboring annotated nodes (structural similarity principle)
- For large networks, modular analysis (e.g., Louvain algorithm) is recommended to avoid visual complexity

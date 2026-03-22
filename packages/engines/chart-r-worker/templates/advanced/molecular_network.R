##############################################################################
##  templates/advanced/molecular_network.R
##  A06 — Molecular network from MS2 cosine similarity (igraph / ggraph)
##
##  md$uns$similarity_matrix : named square matrix of cosine similarities
##  md$var: feature_id, optional logFC, cf_superclass, compound_name
##  params: sim_cut (default 0.7), top_n (default 100 nodes)
##          node_color_by: "superclass" | "logFC" (default "superclass")
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_molecular_network <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("igraph",    quietly = TRUE) ||
      !requireNamespace("ggraph",    quietly = TRUE) ||
      !requireNamespace("tidygraph", quietly = TRUE)) {
    return(.placeholder_plot(
      "igraph + ggraph + tidygraph required\nInstall: install.packages(c('igraph','ggraph','tidygraph'))"
    ))
  }

  sim_mat <- md$uns$similarity_matrix
  if (is.null(sim_mat)) {
    return(.placeholder_plot(
      "molecular_network requires md$uns$similarity_matrix\n(features × features cosine similarity)"
    ))
  }

  sim_cut       <- if (!is.null(params$sim_cut))       params$sim_cut       else 0.7
  top_n         <- if (!is.null(params$top_n))         params$top_n         else 100
  node_color_by <- if (!is.null(params$node_color_by)) params$node_color_by else "superclass"

  var <- md$var

  # Subset to top_n features by connectivity (or top_n most connected)
  sim_mat[sim_mat < sim_cut] <- 0
  diag(sim_mat) <- 0
  n_feat <- min(top_n, nrow(sim_mat))
  degree <- rowSums(sim_mat > 0)
  keep   <- names(sort(degree, decreasing = TRUE))[seq_len(n_feat)]
  sim_sub <- sim_mat[keep, keep, drop = FALSE]

  # Build igraph
  g <- igraph::graph_from_adjacency_matrix(
    sim_sub, mode = "undirected", weighted = TRUE, diag = FALSE
  )

  # Annotate nodes
  node_names <- igraph::V(g)$name
  var_idx    <- match(node_names, var$feature_id)

  if (node_color_by == "logFC" && !is.null(var$logFC)) {
    igraph::V(g)$color_val <- var$logFC[var_idx]
    color_label <- "log2FC"
  } else {
    sc <- if (!is.null(var$cf_superclass)) var$cf_superclass[var_idx] else NA_character_
    igraph::V(g)$color_val <- ifelse(is.na(sc), "Unknown", sc)
    color_label <- "Superclass"
  }

  # Labels: only for highest-degree nodes
  top_deg_mask          <- degree(g) >= quantile(degree(g), 0.8)
  igraph::V(g)$label    <- ""
  if (!is.null(var$compound_name)) {
    igraph::V(g)$label[top_deg_mask] <-
      ifelse(is.na(var$compound_name[var_idx[top_deg_mask]]),
             node_names[top_deg_mask],
             var$compound_name[var_idx[top_deg_mask]])
  }

  tg <- tidygraph::as_tbl_graph(g)

  # Layout: use FR for sparse, KK for dense
  layout_type <- if (igraph::ecount(g) > 500) "fr" else "kk"

  if (node_color_by == "logFC" && !is.null(var$logFC)) {
    ggraph::ggraph(tg, layout = layout_type) +
      ggraph::geom_edge_link(aes(alpha = weight), color = "grey70", show.legend = FALSE) +
      ggraph::geom_node_point(aes(color = color_val), size = 3) +
      ggraph::geom_node_text(aes(label = label), size = 2.5, repel = TRUE) +
      scale_color_gradient2(low = mf_colors$down, mid = "white", high = mf_colors$up,
                            midpoint = 0, name = color_label) +
      labs(title = "Molecular Network", subtitle = sprintf("Cosine similarity ≥ %.2f", sim_cut)) +
      ggraph::theme_graph(base_family = "sans")
  } else {
    n_classes <- length(unique(igraph::V(g)$color_val))
    pal <- setNames(mf_discrete[((seq_len(n_classes) - 1) %% length(mf_discrete)) + 1],
                    unique(igraph::V(g)$color_val))
    ggraph::ggraph(tg, layout = layout_type) +
      ggraph::geom_edge_link(aes(alpha = weight), color = "grey70", show.legend = FALSE) +
      ggraph::geom_node_point(aes(color = color_val), size = 3) +
      ggraph::geom_node_text(aes(label = label), size = 2.5, repel = TRUE) +
      scale_color_manual(values = pal, name = color_label) +
      labs(title = "Molecular Network", subtitle = sprintf("Cosine similarity ≥ %.2f", sim_cut)) +
      ggraph::theme_graph(base_family = "sans")
  }
}

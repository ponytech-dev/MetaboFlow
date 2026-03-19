##############################################################################
##  pathway_ora.R
##  Over-Representation Analysis (ORA) for metabolic pathway enrichment
##
##  Uses KEGGREST to fetch compound-pathway mappings, then runs Fisher's
##  exact test. No dependency on MetaboAnalystR or tidymass.
##############################################################################

## Run KEGG pathway ORA using Fisher's exact test
##
## @param query_ids   character vector of KEGG compound IDs (e.g., "C00001")
## @param organism    KEGG organism code (e.g., "hsa" for human, "ko" for reference)
## @param p_cutoff    significance threshold (default 0.05)
##
## @return data.frame with columns: pathway, pathway_id, total, expected, hits,
##         raw_p, fdr, fold_enrichment, hit_compounds
run_kegg_ora <- function(query_ids,
                          organism = "ko",
                          p_cutoff = 0.05) {
  if (!requireNamespace("KEGGREST", quietly = TRUE)) {
    cat("  KEGGREST not installed, skipping KEGG pathway analysis\n")
    return(data.frame())
  }

  cat("  KEGG ORA: fetching pathway definitions...\n")
  library(KEGGREST)
  old_timeout <- getOption("timeout")
  options(timeout = 120)
  on.exit(options(timeout = old_timeout))

  # Get compound-pathway links
  tryCatch({
    cpd_pw_link <- keggLink("pathway", "compound")
  }, error = function(e) {
    cat("  KEGG API unavailable:", conditionMessage(e), "\n")
    return(data.frame())
  })

  cpd_ids <- sub("cpd:", "", names(cpd_pw_link))
  pw_ids  <- sub("path:map", "", as.character(cpd_pw_link))

  # Get pathway names
  tryCatch({
    org_pathways <- keggList("pathway", organism)
    pw_nums  <- sub(paste0("^", organism), "", names(org_pathways))
    pw_names <- sub(" - .*$", "", as.character(org_pathways))
    pw_name_map <- setNames(pw_names, pw_nums)
  }, error = function(e) {
    cat("  KEGG pathway list unavailable:", conditionMessage(e), "\n")
    return(data.frame())
  })

  # Build pathway compound sets
  pw_cpd_sets <- list()
  all_kegg_cpds <- character()

  for (i in seq_along(pw_nums)) {
    matched_cpds <- cpd_ids[pw_ids == pw_nums[i]]
    if (length(matched_cpds) >= 2) {
      pw_cpd_sets[[pw_nums[i]]] <- matched_cpds
      all_kegg_cpds <- union(all_kegg_cpds, matched_cpds)
    }
  }

  N <- length(all_kegg_cpds)  # universe size
  query_in_universe <- intersect(query_ids, all_kegg_cpds)
  n <- length(query_in_universe)  # query set size

  cat("  Universe:", N, "compounds |", length(pw_cpd_sets), "pathways | Query:", n,
      "of", length(query_ids), "mapped\n")

  if (n < 2) {
    cat("  Too few query compounds mapped to KEGG, skipping ORA\n")
    return(data.frame())
  }

  # Fisher's exact test for each pathway
  results <- list()
  for (pw_num in names(pw_cpd_sets)) {
    pw_cpds <- pw_cpd_sets[[pw_num]]
    K <- length(pw_cpds)  # pathway size
    x <- length(intersect(query_in_universe, pw_cpds))  # hits

    if (x == 0) next

    # One-sided Fisher's exact test (enrichment)
    contingency <- matrix(c(x, n - x, K - x, N - K - n + x), nrow = 2)
    # Ensure no negative values
    if (any(contingency < 0)) next

    p_val <- phyper(x - 1, K, N - K, n, lower.tail = FALSE)
    expected <- n * K / N
    fold_enrich <- if (expected > 0) x / expected else Inf

    hit_cpds <- intersect(query_in_universe, pw_cpds)

    results[[length(results) + 1]] <- data.frame(
      pathway         = ifelse(pw_num %in% names(pw_name_map),
                                pw_name_map[pw_num], pw_num),
      pathway_id      = pw_num,
      total           = K,
      expected        = round(expected, 2),
      hits            = x,
      raw_p           = p_val,
      fold_enrichment = round(fold_enrich, 2),
      hit_compounds   = paste(hit_cpds, collapse = ";"),
      stringsAsFactors = FALSE
    )
  }

  if (length(results) == 0) {
    cat("  No pathways enriched\n")
    return(data.frame())
  }

  out <- do.call(rbind, results)
  out$fdr <- p.adjust(out$raw_p, method = "BH")
  out <- out[order(out$raw_p), ]

  n_sig <- sum(out$raw_p < p_cutoff)
  cat("  Enriched pathways (p<", p_cutoff, "):", n_sig, "of", nrow(out), "\n")
  out
}

## Plot pathway enrichment dot plot (Nature style)
## @param pathway_df  data.frame from run_kegg_ora()
## @param top_n       max pathways to show (default 20)
## @param title       plot title
plot_pathway_dotplot <- function(pathway_df,
                                  top_n = 20,
                                  title = "KEGG Pathway Enrichment") {
  if (nrow(pathway_df) == 0) return(NULL)

  # Top N by p-value
  plot_data <- head(pathway_df[order(pathway_df$raw_p), ], top_n)
  plot_data$neg_log_p <- -log10(plot_data$raw_p)

  # Truncate long pathway names
  plot_data$pathway_short <- ifelse(
    nchar(plot_data$pathway) > 45,
    paste0(substr(plot_data$pathway, 1, 42), "..."),
    plot_data$pathway
  )
  plot_data$pathway_short <- factor(plot_data$pathway_short,
                                     levels = rev(plot_data$pathway_short))

  pathway_gradient <- c("#FEE0D2", "#FC9272", "#DE2D26", "#A50F15")

  p <- ggplot(plot_data, aes(x = hits, y = pathway_short)) +
    geom_point(aes(size = neg_log_p, color = fold_enrichment)) +
    scale_color_gradientn(
      colours = pathway_gradient,
      name = "Fold\nenrichment"
    ) +
    scale_size_continuous(
      range = c(2, 7),
      name = expression(-log[10]*italic(P))
    ) +
    labs(x = "Hit compounds", y = NULL, title = title) +
    theme_classic(base_size = 7) +
    theme(
      axis.text.y = element_text(size = 6),
      axis.text.x = element_text(size = 6),
      axis.title  = element_text(size = 7),
      plot.title  = element_text(size = 8, face = "bold"),
      legend.title = element_text(size = 6),
      legend.text  = element_text(size = 5),
      legend.key.size = unit(3, "mm"),
      panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3)
    )

  p
}

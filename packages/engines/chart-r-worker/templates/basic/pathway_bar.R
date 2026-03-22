##############################################################################
##  templates/basic/pathway_bar.R
##  Pathway enrichment horizontal bar chart — class D
##
##  Data sources (tried in order):
##    1. md$uns$pathway           — data.frame with pathway results
##    2. params$pathway_file      — path to CSV/TSV file
##    3. Placeholder if neither is available
##
##  Required columns in pathway data:
##    pathway_name  (character)
##    p_value       (numeric)
##  Optional columns:
##    p_adjust / padj / fdr  — adjusted p-value (used if present)
##    enrichment_ratio / er  — enrichment ratio (fraction hits / background)
##    hit_count / hits       — number of matched metabolites
##    pathway_size           — total pathway size (for computing er if absent)
##
##  params:
##    top_n       (default 20)   — show top N pathways
##    p_col       (default auto) — column name to use for p-value sorting
##    color_by    (default "er") — "er" | "hit_count" | "p_value"
##    p_cut       (default 0.05) — significance cutoff line
##############################################################################

render_pathway_bar <- function(md, params) {
  # ── Load pathway data ─────────────────────────────────────────────────────
  pw <- NULL

  if (!is.null(md$uns$pathway) && is.data.frame(md$uns$pathway)) {
    pw <- md$uns$pathway
  } else if (!is.null(params$pathway_file) && file.exists(params$pathway_file)) {
    sep <- if (grepl("\\.tsv$", params$pathway_file, ignore.case = TRUE)) "\t" else ","
    pw  <- tryCatch(
      read.table(params$pathway_file, header = TRUE, sep = sep, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
  }

  if (is.null(pw) || nrow(pw) == 0) {
    return(.placeholder_plot(
      "pathway_bar: no pathway data found.\nProvide md$uns$pathway (data.frame) or params$pathway_file (CSV/TSV path).\nRequired columns: pathway_name, p_value"
    ))
  }

  # ── Normalise column names ────────────────────────────────────────────────
  names(pw) <- trimws(tolower(names(pw)))

  if (!"pathway_name" %in% names(pw)) {
    # Try common aliases
    alias <- c("pathway", "name", "term", "description", "id")
    found <- intersect(alias, names(pw))
    if (length(found) == 0) {
      return(.placeholder_plot("pathway_bar: could not find 'pathway_name' column in pathway data"))
    }
    names(pw)[names(pw) == found[1]] <- "pathway_name"
  }

  # p-value column
  p_col <- params$p_col
  if (is.null(p_col)) {
    p_col <- intersect(c("p_adjust", "padj", "fdr", "p.adjust", "p_value", "pvalue", "p.value"), names(pw))[1]
  }
  if (is.null(p_col) || !p_col %in% names(pw)) {
    return(.placeholder_plot(
      "pathway_bar: could not identify p-value column.\nExpected: p_value, p_adjust, padj, or fdr"
    ))
  }

  pw$p_val <- as.numeric(pw[[p_col]])
  pw       <- pw[!is.na(pw$p_val) & is.finite(pw$p_val), ]

  # ── Enrichment ratio ──────────────────────────────────────────────────────
  er_col <- intersect(c("enrichment_ratio", "er", "enrichment.ratio", "fold_enrichment"), names(pw))[1]
  if (!is.na(er_col) && er_col %in% names(pw)) {
    pw$er <- as.numeric(pw[[er_col]])
  } else if (all(c("hit_count", "pathway_size") %in% names(pw)) ||
             all(c("hits", "pathway_size") %in% names(pw))) {
    hc_col <- intersect(c("hit_count", "hits"), names(pw))[1]
    pw$er  <- as.numeric(pw[[hc_col]]) / as.numeric(pw$pathway_size)
  } else {
    pw$er <- NA_real_
  }

  # Hit count
  hc_col <- intersect(c("hit_count", "hits", "count"), names(pw))[1]
  pw$hit_count <- if (!is.na(hc_col) && hc_col %in% names(pw)) as.numeric(pw[[hc_col]]) else NA_real_

  # ── Sort and trim ─────────────────────────────────────────────────────────
  top_n  <- if (!is.null(params$top_n)) as.integer(params$top_n) else 20L
  p_cut  <- if (!is.null(params$p_cut)) as.numeric(params$p_cut) else 0.05

  pw     <- pw[order(pw$p_val), ]
  pw     <- pw[seq_len(min(top_n, nrow(pw))), ]
  pw$log_p <- -log10(pw$p_val)
  pw$pathway_name <- factor(pw$pathway_name, levels = rev(pw$pathway_name))

  color_by <- if (!is.null(params$color_by)) params$color_by else "er"

  # Determine fill aesthetic
  if (color_by == "hit_count" && !all(is.na(pw$hit_count))) {
    fill_col  <- pw$hit_count
    fill_name <- "Hit Count"
  } else if (color_by == "p_value") {
    fill_col  <- pw$log_p
    fill_name <- expression(-log[10](p))
  } else if (!all(is.na(pw$er))) {
    fill_col  <- pw$er
    fill_name <- "Enrichment\nRatio"
  } else {
    fill_col  <- pw$log_p
    fill_name <- expression(-log[10](p))
  }
  pw$fill_val <- fill_col

  ggplot(pw, aes(x = log_p, y = pathway_name, fill = fill_val)) +
    geom_col(width = 0.7) +
    geom_vline(xintercept = -log10(p_cut), linetype = "dashed", color = "grey40", linewidth = 0.5) +
    scale_fill_gradientn(
      colors = mf_pathway(100),
      name   = fill_name
    ) +
    labs(
      title    = "Pathway Enrichment",
      subtitle = sprintf("Top %d pathways | sorted by %s", nrow(pw), p_col),
      x        = expression(-log[10](p-value)),
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(axis.text.y = element_text(size = 8))
}

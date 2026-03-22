##############################################################################
##  templates/basic/pathway_bubble.R
##  Pathway enrichment bubble plot — class D
##
##  Same data sources as pathway_bar.R:
##    md$uns$pathway (data.frame) or params$pathway_file (CSV/TSV)
##
##  Axes:
##    x = enrichment ratio (or hit_count if er absent)
##    y = pathway name (sorted by ascending p-value, i.e. top at top)
##  Bubble size  = hit count (or 1 if absent)
##  Bubble color = -log10(p_value), using viridis-c
##
##  params:
##    top_n    (default 25)
##    p_cut    (default 0.05) — grey cutoff line
##    p_col    (default auto)
##    max_size (default 8)    — largest bubble point size
##    min_size (default 2)    — smallest bubble point size
##############################################################################

render_pathway_bubble <- function(md, params) {
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
      "pathway_bubble: no pathway data found.\nProvide md$uns$pathway (data.frame) or params$pathway_file (CSV/TSV path).\nRequired columns: pathway_name, p_value"
    ))
  }

  # ── Normalise column names ────────────────────────────────────────────────
  names(pw) <- trimws(tolower(names(pw)))

  if (!"pathway_name" %in% names(pw)) {
    alias <- c("pathway", "name", "term", "description", "id")
    found <- intersect(alias, names(pw))
    if (length(found) == 0) {
      return(.placeholder_plot("pathway_bubble: could not find 'pathway_name' column"))
    }
    names(pw)[names(pw) == found[1]] <- "pathway_name"
  }

  p_col <- params$p_col
  if (is.null(p_col)) {
    p_col <- intersect(c("p_adjust", "padj", "fdr", "p.adjust", "p_value", "pvalue", "p.value"), names(pw))[1]
  }
  if (is.null(p_col) || !p_col %in% names(pw)) {
    return(.placeholder_plot(
      "pathway_bubble: could not identify p-value column.\nExpected: p_value, p_adjust, padj, or fdr"
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

  # Hit count — used as bubble size
  hc_col <- intersect(c("hit_count", "hits", "count"), names(pw))[1]
  pw$hit_count <- if (!is.na(hc_col) && hc_col %in% names(pw)) {
    as.numeric(pw[[hc_col]])
  } else {
    rep(3, nrow(pw))   # uniform size fallback
  }

  # ── Sort and trim ─────────────────────────────────────────────────────────
  top_n    <- if (!is.null(params$top_n))    as.integer(params$top_n)    else 25L
  p_cut    <- if (!is.null(params$p_cut))    as.numeric(params$p_cut)    else 0.05
  max_size <- if (!is.null(params$max_size)) as.numeric(params$max_size) else 8
  min_size <- if (!is.null(params$min_size)) as.numeric(params$min_size) else 2

  pw        <- pw[order(pw$p_val), ]
  pw        <- pw[seq_len(min(top_n, nrow(pw))), ]
  pw$log_p  <- -log10(pw$p_val)

  # y-axis: pathways sorted by p-value (smallest p = top of plot)
  pw$pathway_name <- factor(pw$pathway_name, levels = rev(pw$pathway_name))

  # x-axis: enrichment ratio or hit_count if er is absent
  if (!all(is.na(pw$er))) {
    x_var  <- pw$er
    x_lab  <- "Enrichment Ratio"
  } else {
    x_var  <- pw$hit_count
    x_lab  <- "Hit Count"
  }
  pw$x_val <- x_var

  ggplot(pw, aes(x = x_val, y = pathway_name, size = hit_count, color = log_p)) +
    geom_point(alpha = 0.85) +
    geom_vline(
      xintercept = if (!all(is.na(pw$er))) 1 else NA_real_,
      linetype = "dashed", color = "grey50", linewidth = 0.4
    ) +
    scale_size_continuous(
      range = c(min_size, max_size),
      name  = "Hit Count"
    ) +
    scale_color_viridis_c(
      name   = expression(-log[10](p)),
      option = "D",
      direction = -1
    ) +
    labs(
      title    = "Pathway Enrichment Bubble Plot",
      subtitle = sprintf("Top %d pathways | color = -log10(p) | size = hit count", nrow(pw)),
      x        = x_lab,
      y        = NULL
    ) +
    theme_metaboflow() +
    theme(axis.text.y = element_text(size = 8))
}

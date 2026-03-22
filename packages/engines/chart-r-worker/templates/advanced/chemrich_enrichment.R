##############################################################################
##  templates/advanced/chemrich_enrichment.R
##  A18 — ChemRICH chemical enrichment bubble plot
##
##  md$uns$chemrich_results: data.frame with columns:
##    set_name (chemical class), p_value, effect_ratio,
##    all_compounds (total in set), sig_up (up-regulated), sig_down (down-regulated)
##  OR md$var with cf_superclass, logFC, pvalue — auto-computes enrichment
##
##  params: p_cut (default 0.05), min_compounds (default 3)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_chemrich_enrichment <- function(md, params) {
  library(ggplot2)
  library(ggrepel)

  p_cut        <- if (!is.null(params$p_cut))        params$p_cut        else 0.05
  min_compounds <- if (!is.null(params$min_compounds)) params$min_compounds else 3

  res_df <- md$uns$chemrich_results

  # Auto-compute from md$var if results not provided
  if (is.null(res_df)) {
    var <- md$var
    if (is.null(var$cf_superclass) || is.null(var$logFC) || is.null(var$pvalue)) {
      return(.placeholder_plot(
        "chemrich_enrichment requires md$uns$chemrich_results\nOR md$var with cf_superclass, logFC, pvalue"
      ))
    }

    var <- var[!is.na(var$cf_superclass), ]
    sets <- split(var, var$cf_superclass)

    res_df <- do.call(rbind, lapply(names(sets), function(set_name) {
      s      <- sets[[set_name]]
      n_all  <- nrow(s)
      if (n_all < min_compounds) return(NULL)

      sig    <- !is.na(s$pvalue) & s$pvalue <= p_cut
      n_up   <- sum(sig & s$logFC > 0, na.rm = TRUE)
      n_down <- sum(sig & s$logFC < 0, na.rm = TRUE)
      n_sig  <- n_up + n_down

      # Kolmogorov-Smirnov test on logFC distribution
      bg_fc   <- var$logFC[!is.na(var$logFC)]
      set_fc  <- s$logFC[!is.na(s$logFC)]
      p_val   <- if (length(set_fc) >= 2 && length(bg_fc) >= 2) {
        tryCatch(ks.test(set_fc, bg_fc)$p.value, error = function(e) NA_real_)
      } else NA_real_

      data.frame(
        set_name      = set_name,
        p_value       = p_val,
        all_compounds = n_all,
        sig_up        = n_up,
        sig_down      = n_down,
        effect_ratio  = n_sig / n_all,
        stringsAsFactors = FALSE
      )
    }))

    if (is.null(res_df) || nrow(res_df) == 0) {
      return(.placeholder_plot("No chemical classes with sufficient features"))
    }
  }

  # Filter
  res_df <- res_df[!is.na(res_df$p_value), ]
  res_df$neg_log10_p <- -log10(pmax(res_df$p_value, 1e-300))
  res_df$sig         <- res_df$p_value <= p_cut

  # Up/down ratio for color: positive = more up, negative = more down
  if (!is.null(res_df$sig_up) && !is.null(res_df$sig_down)) {
    total_sig        <- res_df$sig_up + res_df$sig_down + 0.01
    res_df$direction <- (res_df$sig_up - res_df$sig_down) / total_sig
  } else {
    res_df$direction <- 0
  }

  # Layout: x = effect_ratio, y = -log10p, size = all_compounds, color = direction
  ggplot(res_df, aes(x = effect_ratio, y = neg_log10_p)) +
    geom_hline(yintercept = -log10(p_cut), linetype = "dashed", color = "grey60") +
    geom_point(aes(size = all_compounds, fill = direction),
               shape = 21, color = "white", alpha = 0.85) +
    geom_text_repel(
      data = res_df[res_df$sig, ],
      aes(label = set_name), size = 3,
      max.overlaps = 20, segment.color = "grey50"
    ) +
    scale_fill_gradient2(
      low = mf_colors$down, mid = "white", high = mf_colors$up,
      midpoint = 0, name = "Direction\n(Up − Down)"
    ) +
    scale_size_continuous(range = c(3, 12), name = "Compounds") +
    labs(
      title    = "ChemRICH Chemical Enrichment",
      subtitle = sprintf("p ≤ %g highlighted", p_cut),
      x        = "Effect Ratio (Sig / Total)",
      y        = "-log10(p-value)"
    ) +
    theme_metaboflow() +
    theme(legend.position = "right")
}

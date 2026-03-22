##############################################################################
##  templates/basic/upset_plot.R
##  UpSet / Venn plot for multi-group differential feature overlap — class A
##
##  Requires md$var$significant (logical/integer) AND md$obs$group, OR
##  md$var columns named after groups with logical TRUE/FALSE membership.
##
##  Logic:
##    - Determine per-group significant feature sets from md$var
##    - If 2 groups → simple Venn via ggplot (two overlapping circles + counts)
##    - If 3+ groups → UpSet via ComplexHeatmap::UpSet (preferred) or
##                     UpSetR::upset as fallback, wrapped as grid grob
##
##  Membership detection (in priority order):
##    A. md$uns$group_sig_features — named list of feature_id vectors per group
##    B. md$var columns that match group names in md$obs$group — logical/integer
##    C. md$var$significant + group from pairwise comparison stored in md$uns$comparison_group
##
##  params:
##    min_set_size (default 0) — minimum set size to include in UpSet
##    n_intersections (default 40) — max intersections to display
##    order_by (default "freq") — "freq" | "degree"
##############################################################################

render_upset_plot <- function(md, params) {
  # ── Resolve membership sets ───────────────────────────────────────────────
  sets <- NULL

  # Priority A: pre-computed sets in uns
  if (!is.null(md$uns$group_sig_features) && is.list(md$uns$group_sig_features)) {
    sets <- lapply(md$uns$group_sig_features, function(x) as.character(x))
  }

  # Priority B: logical/integer columns in var matching group names
  if (is.null(sets) && !is.null(md$var) && !is.null(md$obs$group)) {
    groups      <- unique(md$obs$group)
    var_names   <- names(md$var)
    matched_cols <- intersect(groups, var_names)
    if (length(matched_cols) >= 2) {
      sets <- lapply(setNames(matched_cols, matched_cols), function(g) {
        vals <- md$var[[g]]
        md$var$feature_id[!is.na(vals) & as.logical(vals)]
      })
    }
  }

  # Priority C: md$var$significant with a single comparison group annotation
  if (is.null(sets) && !is.null(md$var$significant)) {
    sig_fids <- md$var$feature_id[!is.na(md$var$significant) & as.logical(md$var$significant)]
    if (!is.null(md$uns$comparison_group) && length(md$uns$comparison_group) == 1) {
      sets <- list()
      sets[[md$uns$comparison_group]] <- sig_fids
    } else if (!is.null(md$obs$group)) {
      # Generic: assign all significant features to all groups (rough fallback)
      groups <- unique(md$obs$group)
      sets   <- setNames(replicate(length(groups), sig_fids, simplify = FALSE), groups)
    }
  }

  if (is.null(sets) || length(sets) < 2) {
    return(.placeholder_plot(
      "upset_plot: need at least 2 group feature sets.\nPopulate md$uns$group_sig_features as a named list,\nor add group-name columns to md$var with logical membership."
    ))
  }

  # Remove empty sets
  sets <- Filter(function(x) length(x) > 0, sets)
  if (length(sets) < 2) {
    return(.placeholder_plot("upset_plot: fewer than 2 non-empty feature sets after filtering"))
  }

  n_groups    <- length(sets)
  min_set     <- if (!is.null(params$min_set_size))    as.integer(params$min_set_size)    else 0L
  n_inter     <- if (!is.null(params$n_intersections)) as.integer(params$n_intersections) else 40L
  order_by    <- if (!is.null(params$order_by))        params$order_by                    else "freq"

  # ── Two-group: simple Venn diagram ────────────────────────────────────────
  if (n_groups == 2) {
    g_names  <- names(sets)
    only_a   <- length(setdiff(sets[[1]], sets[[2]]))
    only_b   <- length(setdiff(sets[[2]], sets[[1]]))
    both     <- length(intersect(sets[[1]], sets[[2]]))
    total_a  <- length(sets[[1]])
    total_b  <- length(sets[[2]])

    # Build circles manually with trigonometry
    .circle_poly <- function(cx, cy, r, n = 200) {
      theta <- seq(0, 2 * pi, length.out = n + 1)
      data.frame(x = cx + r * cos(theta), y = cy + r * sin(theta))
    }
    c1 <- .circle_poly(-0.7, 0, 1.4)
    c2 <- .circle_poly( 0.7, 0, 1.4)
    c1$group <- g_names[1]
    c2$group <- g_names[2]
    circles  <- rbind(c1, c2)

    p <- ggplot() +
      geom_polygon(
        data    = circles[circles$group == g_names[1], ],
        mapping = aes(x = x, y = y),
        fill    = mf_discrete[1], alpha = 0.3, color = mf_discrete[1], linewidth = 0.8
      ) +
      geom_polygon(
        data    = circles[circles$group == g_names[2], ],
        mapping = aes(x = x, y = y),
        fill    = mf_discrete[2], alpha = 0.3, color = mf_discrete[2], linewidth = 0.8
      ) +
      # Labels inside circles
      annotate("text", x = -1.5, y =  0.0, label = g_names[1],  size = 4.5, fontface = "bold", color = mf_discrete[1]) +
      annotate("text", x =  1.5, y =  0.0, label = g_names[2],  size = 4.5, fontface = "bold", color = mf_discrete[2]) +
      # Counts
      annotate("text", x = -1.2, y =  0.0, label = only_a, size = 5, fontface = "bold") +
      annotate("text", x =  0.0, y =  0.0, label = both,   size = 5, fontface = "bold") +
      annotate("text", x =  1.2, y =  0.0, label = only_b, size = 5, fontface = "bold") +
      # Legend-style subtitles
      annotate("text", x = -1.2, y = -0.3, label = sprintf("only %s", g_names[1]), size = 3, color = "grey40") +
      annotate("text", x =  0.0, y = -0.3, label = "shared", size = 3, color = "grey40") +
      annotate("text", x =  1.2, y = -0.3, label = sprintf("only %s", g_names[2]), size = 3, color = "grey40") +
      coord_equal() +
      xlim(-3, 3) + ylim(-2, 2) +
      labs(
        title    = "Feature Overlap (Venn Diagram)",
        subtitle = sprintf("%s: %d | %s: %d | shared: %d", g_names[1], total_a, g_names[2], total_b, both)
      ) +
      theme_void() +
      theme(
        plot.title    = element_text(face = "bold", size = 13, hjust = 0.5),
        plot.subtitle = element_text(size = 10, hjust = 0.5, color = "grey40")
      )
    return(p)
  }

  # ── Three or more groups: UpSet plot ─────────────────────────────────────
  # Build binary membership matrix
  all_features <- unique(unlist(sets))
  if (length(all_features) == 0) {
    return(.placeholder_plot("upset_plot: all feature sets are empty"))
  }

  mat <- do.call(cbind, lapply(sets, function(s) as.integer(all_features %in% s)))
  rownames(mat) <- all_features
  colnames(mat) <- names(sets)

  # Remove features not in any set (should not happen, but guard)
  mat <- mat[rowSums(mat) > 0, , drop = FALSE]

  # Filter min set size
  col_sums <- colSums(mat)
  keep_cols <- col_sums >= min_set
  if (sum(keep_cols) < 2) {
    return(.placeholder_plot(
      sprintf("upset_plot: fewer than 2 sets with size >= %d", min_set)
    ))
  }
  mat <- mat[, keep_cols, drop = FALSE]

  # Prefer ComplexHeatmap::UpSet (returns a Heatmap — can be drawn via grid)
  if (requireNamespace("ComplexHeatmap", quietly = TRUE)) {
    m <- ComplexHeatmap::make_comb_mat(mat)
    if (!is.null(n_inter)) m <- m[ComplexHeatmap::comb_size(m) > 0]

    # Return the UpSet object; the rendering layer should call draw() or
    # wrap via cowplot::as_grob / grid::grid.grabExpr
    # We wrap it so it integrates with the ggplot-based pipeline
    upset_obj <- ComplexHeatmap::UpSet(
      m,
      top_annotation = ComplexHeatmap::upset_top_annotation(m, add_numbers = TRUE),
      set_order      = order(ComplexHeatmap::set_size(m), decreasing = TRUE),
      comb_order     = if (order_by == "freq") {
        order(ComplexHeatmap::comb_size(m), decreasing = TRUE)
      } else {
        order(ComplexHeatmap::comb_degree(m))
      }
    )

    # Capture as a ggplot-compatible object via recordPlot / cowplot
    if (requireNamespace("cowplot", quietly = TRUE)) {
      grob <- cowplot::as_grob(function() {
        ComplexHeatmap::draw(upset_obj)
      })
      return(cowplot::ggdraw(grob))
    } else {
      # Return a placeholder with instructions — ComplexHeatmap::draw() must
      # be called directly by the caller
      attr(upset_obj, "render_type") <- "ComplexHeatmap"
      return(upset_obj)
    }

  } else if (requireNamespace("UpSetR", quietly = TRUE)) {
    # UpSetR returns a base R plot — wrap via recordPlot
    mat_df <- as.data.frame(mat)
    order_arg <- if (order_by == "freq") "freq" else "degree"

    if (requireNamespace("cowplot", quietly = TRUE)) {
      grob <- cowplot::as_grob(function() {
        UpSetR::upset(
          mat_df,
          sets                  = colnames(mat_df),
          order.by              = order_arg,
          nintersects           = n_inter,
          mb.ratio              = c(0.6, 0.4),
          main.bar.color        = mf_colors$up,
          sets.bar.color        = mf_colors$down,
          text.scale            = 1.2
        )
      })
      return(cowplot::ggdraw(grob))
    } else {
      # Last resort: basic bar chart of intersection sizes
      .upset_fallback_bar(mat, order_by, n_inter)
    }

  } else {
    # No UpSet package available — draw a basic intersection bar chart
    .upset_fallback_bar(mat, order_by, n_inter)
  }
}

# ---------------------------------------------------------------------------
# Internal: simple intersection bar chart when no UpSet package is available
# ---------------------------------------------------------------------------
.upset_fallback_bar <- function(mat, order_by = "freq", n_inter = 40) {
  # Compute all intersection sizes
  combo_labels <- apply(mat, 1, function(row) paste(names(which(row == 1L)), collapse = " & "))
  inter_df     <- as.data.frame(table(combo_labels), stringsAsFactors = FALSE)
  names(inter_df) <- c("intersection", "size")
  inter_df <- inter_df[inter_df$size > 0, ]

  if (order_by == "freq") {
    inter_df <- inter_df[order(inter_df$size, decreasing = TRUE), ]
  } else {
    inter_df$degree <- sapply(strsplit(inter_df$intersection, " & "), length)
    inter_df <- inter_df[order(inter_df$degree, inter_df$size, decreasing = c(FALSE, TRUE)), ]
  }
  inter_df <- inter_df[seq_len(min(n_inter, nrow(inter_df))), ]
  inter_df$intersection <- factor(inter_df$intersection, levels = rev(inter_df$intersection))

  ggplot(inter_df, aes(x = size, y = intersection)) +
    geom_col(fill = mf_colors$down, width = 0.7) +
    geom_text(aes(label = size), hjust = -0.2, size = 3) +
    labs(
      title    = "Feature Overlap — Intersection Sizes",
      subtitle = sprintf("Install ComplexHeatmap or UpSetR for a proper UpSet plot | showing top %d intersections", nrow(inter_df)),
      x        = "Number of Features",
      y        = "Intersection"
    ) +
    theme_metaboflow() +
    theme(axis.text.y = element_text(size = 8))
}

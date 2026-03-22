##############################################################################
##  templates/advanced/treemap_classes.R
##  A19 — Treemap by chemical class (ClassyFire hierarchy)
##
##  md$var: feature_id, optional cf_superclass, cf_class, cf_subclass
##  params: level: "superclass" | "class" | "subclass" (default "class")
##          min_count (default 2)
##############################################################################

.placeholder_plot <- function(msg) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = msg, size = 5, color = "grey50") +
    ggplot2::theme_void() + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

render_treemap_classes <- function(md, params) {
  library(ggplot2)

  if (!requireNamespace("treemap", quietly = TRUE)) {
    return(.placeholder_plot(
      "treemap package required\nInstall: install.packages('treemap')"
    ))
  }

  var       <- md$var
  level     <- if (!is.null(params$level))     params$level     else "class"
  min_count <- if (!is.null(params$min_count)) params$min_count else 2

  # Determine columns to use
  col_map <- list(
    superclass = "cf_superclass",
    class      = "cf_class",
    subclass   = "cf_subclass"
  )

  primary_col <- col_map[[level]]
  if (is.null(primary_col) || is.null(var[[primary_col]])) {
    # Try any available ClassyFire column
    available <- names(col_map)[sapply(col_map, function(c) !is.null(var[[c]]))]
    if (length(available) == 0) {
      return(.placeholder_plot(
        "treemap_classes requires cf_superclass, cf_class, or cf_subclass in md$var"
      ))
    }
    primary_col <- col_map[[available[1]]]
    warning(sprintf("treemap_classes: using '%s' (requested '%s' not available)", primary_col, level))
  }

  df <- var[!is.na(var[[primary_col]]), ]
  if (nrow(df) == 0) {
    return(.placeholder_plot(sprintf("All '%s' values are NA", primary_col)))
  }

  # Hierarchical structure: superclass → class (or class → subclass)
  has_super <- !is.null(var$cf_superclass) && any(!is.na(var$cf_superclass))

  if (level == "subclass" && has_super && !is.null(var$cf_class)) {
    df$group1 <- ifelse(is.na(df$cf_class),      "Unknown Class",      df$cf_class)
    df$group2 <- ifelse(is.na(df$cf_subclass),   "Unknown Subclass",   df$cf_subclass)
  } else if (level == "class" && has_super) {
    df$group1 <- ifelse(is.na(df$cf_superclass), "Unknown Superclass", df$cf_superclass)
    df$group2 <- ifelse(is.na(df$cf_class),      "Unknown Class",      df$cf_class)
  } else {
    df$group1 <- "All Metabolites"
    df$group2 <- df[[primary_col]]
  }

  # Count
  count_df <- as.data.frame(table(group1 = df$group1, group2 = df$group2))
  count_df <- count_df[count_df$Freq >= min_count, ]

  if (nrow(count_df) == 0) {
    return(.placeholder_plot(sprintf("No classes with count ≥ %d", min_count)))
  }

  # Assign superclass colors
  super_classes  <- unique(count_df$group1)
  n_super        <- length(super_classes)
  super_pal      <- setNames(
    mf_discrete[((seq_len(n_super) - 1) %% length(mf_discrete)) + 1],
    super_classes
  )
  count_df$color <- super_pal[count_df$group1]

  # treemap returns a grob — capture and embed
  tmp_file <- tempfile(fileext = ".png")
  png(tmp_file, width = 800, height = 600)

  treemap::treemap(
    count_df,
    index       = c("group1", "group2"),
    vSize       = "Freq",
    vColor      = "color",
    type        = "color",
    palette     = mf_discrete,
    title       = sprintf("Chemical Class Treemap (%s level)", level),
    fontsize.labels = c(12, 9),
    fontcolor.labels = c("white", "grey20"),
    overlap.labels  = 0.5,
    border.col  = "white"
  )
  dev.off()

  img  <- png::readPNG(tmp_file)
  grob <- grid::rasterGrob(img, interpolate = TRUE)

  ggplot() +
    annotation_custom(grob, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
    labs(title = sprintf("Chemical Class Treemap — %s level", level)) +
    theme_void()
}

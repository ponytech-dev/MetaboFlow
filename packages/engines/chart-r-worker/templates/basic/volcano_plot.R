##############################################################################
##  templates/basic/volcano_plot.R
##  Differential metabolites volcano plot using EnhancedVolcano
##
##  md$var must contain: feature_id, logFC, pvalue
##  Optional: compound_name (used as labels instead of feature_id)
##  params: fc_cut (default 1), p_cut (default 0.05)
##############################################################################

render_volcano_plot <- function(md, params) {
  library(EnhancedVolcano)

  var <- md$var
  if (is.null(var$logFC) || is.null(var$pvalue)) {
    stop("volcano_plot requires md$var$logFC and md$var$pvalue — run stats first")
  }

  fc_cut <- if (!is.null(params$fc_cut)) params$fc_cut else 1
  p_cut  <- if (!is.null(params$p_cut))  params$p_cut  else 0.05

  labels <- if (!is.null(var$compound_name) && any(!is.na(var$compound_name))) {
    ifelse(is.na(var$compound_name), var$feature_id, var$compound_name)
  } else {
    var$feature_id
  }

  EnhancedVolcano(
    var,
    lab      = labels,
    x        = "logFC",
    y        = "pvalue",
    pCutoff  = p_cut,
    FCcutoff = fc_cut,
    # EnhancedVolcano 4-color vector: NS, logFC only, p only, sig+logFC
    col = c(
      mf_colors$not_significant,
      mf_colors$not_significant,
      mf_colors$not_significant,
      mf_colors$up
    ),
    colAlpha         = 0.8,
    title            = "Differential Metabolites",
    subtitle         = sprintf("FC cutoff: %g | p-value cutoff: %g", fc_cut, p_cut),
    pointSize        = 2,
    labSize          = 3,
    drawConnectors   = TRUE,
    widthConnectors  = 0.5,
    colConnectors    = "grey50",
    legendPosition   = "right"
  ) +
    theme_metaboflow()
}

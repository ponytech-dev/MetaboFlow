##############################################################################
##  chart-r-worker/R/metaboflow_theme.R
##  MetaboFlow Publication Theme — Nature Journal Style
##
##  Based on Nature journal submission guidelines:
##    - Helvetica/Arial fonts
##    - Minimal gridlines
##    - Clean axes
##    - No background fill
##
##  Dependencies: ggplot2
##############################################################################

library(ggplot2)

theme_metaboflow <- function(base_size = 12, base_family = "Helvetica") {
  theme_classic(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # Text
      plot.title    = element_text(size = base_size * 1.2, face = "bold",
                                   hjust = 0, margin = margin(b = 10)),
      plot.subtitle = element_text(size = base_size * 0.9, color = "grey30",
                                   margin = margin(b = 10)),
      axis.title    = element_text(size = base_size, face = "bold"),
      axis.text     = element_text(size = base_size * 0.85, color = "black"),
      legend.title  = element_text(size = base_size * 0.9, face = "bold"),
      legend.text   = element_text(size = base_size * 0.85),
      strip.text    = element_text(size = base_size * 0.9, face = "bold"),

      # Axes
      axis.line  = element_line(color = "black", linewidth = 0.5),
      axis.ticks = element_line(color = "black", linewidth = 0.3),

      # Grid — minimal (Nature style: no grid)
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.background = element_blank(),
      plot.background  = element_blank(),

      # Legend
      legend.background = element_blank(),
      legend.key        = element_blank(),
      legend.position   = "right",

      # Strip (facets)
      strip.background = element_blank(),

      # Margins
      plot.margin = margin(15, 15, 15, 15)
    )
}

# Apply theme globally when sourced
theme_set(theme_metaboflow())

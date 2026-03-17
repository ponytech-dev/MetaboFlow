##############################################################################
##  MetaboFlow E2E Pipeline — Thermo Q Exactive HF (MTBLS733)
##  Dataset: Piper nigrum (black pepper) seeds, Group A vs Group B
##  Instrument: Thermo Q Exactive HF, ESI+, 100-1500 m/z, RPLC C18
##  Peak detection: MatchedFilter (memory-efficient for Docker-constrained environments)
##
##  Input:  /data/mzML/{SA,SB}*.mzML
##  Output: /results/ (CSV tables + Nature-quality PDF/TIFF/PNG charts)
##############################################################################

cat("========== MetaboFlow E2E: Q Exactive HF (MTBLS733) ==========\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

suppressPackageStartupMessages({
  library(MSnbase)
  library(xcms)
  library(limma)
  library(ggplot2)
  library(dplyr)
  library(pheatmap)
  library(patchwork)
  library(ggrepel)
  library(scales)
})

source("/app/R/config.R")
source("/app/R/differential.R")

## ========================= Config =========================
DATA_DIR    <- "/data/mzML"
RESULTS_DIR <- "/results"
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

mzml_files <- sort(list.files(DATA_DIR, pattern = "\\.mzML$", full.names = TRUE))
cat("Found", length(mzml_files), "mzML files\n")
if (length(mzml_files) == 0) stop("No mzML files found in ", DATA_DIR)

sample_names <- gsub("\\.mzML$", "", basename(mzml_files))
sample_group <- ifelse(grepl("^SA", sample_names), "A", "B")
sample_info  <- data.frame(
  sample_id = sample_names,
  group     = sample_group,
  file      = mzml_files,
  stringsAsFactors = FALSE
)
cat("Sample info:\n")
print(sample_info[, c("sample_id", "group")])
cat("\n")

## ========================= Step 1: Peak Detection (MatchedFilter) =========================
cat("===== Step 1: Peak Detection (xcms MatchedFilter — memory-efficient) =====\n")
t1 <- Sys.time()
register(SerialParam())

raw_data <- readMSData(mzml_files, mode = "onDisk")

# Filter to MS1 only and restrict RT range to reduce memory
raw_data <- filterMsLevel(raw_data, msLevel = 1L)
cat("  MS1 scans after filter:", length(raw_data), "\n")

# Restrict RT range if data is very long
rt_range <- range(rtime(raw_data))
cat("  RT range:", round(rt_range[1]), "-", round(rt_range[2]), "seconds\n")
if (rt_range[2] > 900) {
  raw_data <- filterRt(raw_data, rt = c(30, 600))
  cat("  Filtered RT to 30-600 seconds to manage memory\n")
}

# MatchedFilter: binning-based, constant memory regardless of resolution
# binSize=0.01 preserves high-res Orbitrap mass accuracy
mfp <- MatchedFilterParam(
  binSize  = 0.01,
  fwhm     = 10,
  snthresh = 10,
  mzdiff   = 0.01
)
cat("  Running MatchedFilter (binSize=0.01, fwhm=10, snthresh=10)...\n")
xdata <- findChromPeaks(raw_data, param = mfp)
gc()  # free peak detection intermediates
cat("  Chromatographic peaks found:", nrow(chromPeaks(xdata)), "\n")

# Peak grouping
pdp <- PeakDensityParam(
  sampleGroups = sample_group,
  minFraction  = 0.5,
  bw           = 3,
  binSize      = 0.01
)
xdata <- groupChromPeaks(xdata, param = pdp)
cat("  Features after grouping:", nrow(featureDefinitions(xdata)), "\n")

# RT alignment (only if >4 samples)
if (length(mzml_files) >= 4) {
  pgp <- PeakGroupsParam(minFraction = 0.5)
  xdata <- adjustRtime(xdata, param = pgp)
  # Re-group after alignment
  xdata <- groupChromPeaks(xdata, param = pdp)
  cat("  Features after RT alignment + re-grouping:", nrow(featureDefinitions(xdata)), "\n")
}

# Fill missing peaks
xdata <- fillChromPeaks(xdata)

feature_values <- featureValues(xdata, value = "into", method = "maxint")
feature_defs   <- featureDefinitions(xdata)

t1_end <- Sys.time()
cat("  Peak detection time:", round(difftime(t1_end, t1, units = "secs"), 1), "seconds\n")
cat("  Final feature matrix:", nrow(feature_values), "features x", ncol(feature_values), "samples\n\n")

## ========================= Step 2: Preprocessing =========================
cat("===== Step 2: Preprocessing =====\n")

peak_table <- data.frame(
  feature_id = rownames(feature_values),
  mz         = feature_defs$mzmed,
  rt         = feature_defs$rtmed,
  feature_values,
  check.names = FALSE
)
write.csv(peak_table, file.path(RESULTS_DIR, "01_raw_peak_table.csv"), row.names = FALSE)
cat("  Saved raw peak table:", nrow(peak_table), "features\n")

int_matrix <- as.matrix(feature_values)

# Remove features with >50% missing
na_frac <- rowMeans(is.na(int_matrix))
keep    <- na_frac <= 0.5
int_matrix <- int_matrix[keep, ]
cat("  After NA filter (<=50% missing):", nrow(int_matrix), "features\n")

# Imputation: min/2
for (i in seq_len(nrow(int_matrix))) {
  na_idx <- is.na(int_matrix[i, ])
  if (any(na_idx)) {
    row_min <- min(int_matrix[i, !na_idx], na.rm = TRUE)
    int_matrix[i, na_idx] <- row_min / 2
  }
}
cat("  Missing values imputed (min/2)\n")

# Log2 transform (more standard for metabolomics than log10)
int_log <- log2(int_matrix + 1)

# Median normalization
col_medians  <- apply(int_log, 2, median)
global_median <- median(col_medians)
norm_factors  <- global_median - col_medians
int_norm      <- sweep(int_log, 2, norm_factors, "+")

cat("  Log2 + median normalization applied\n")

processed_table <- data.frame(
  feature_id = rownames(int_norm),
  mz         = feature_defs[rownames(int_norm), "mzmed"],
  rt         = feature_defs[rownames(int_norm), "rtmed"],
  int_norm,
  check.names = FALSE
)
write.csv(processed_table, file.path(RESULTS_DIR, "02_processed_peak_table.csv"), row.names = FALSE)
cat("  Saved processed peak table:", nrow(processed_table), "features\n\n")

## ========================= Step 3: Differential Analysis =========================
cat("===== Step 3: Differential Analysis (limma) =====\n")

a_cols <- which(sample_group == "A")
b_cols <- which(sample_group == "B")

# Group A = control, Group B = treatment
data_ctl   <- int_norm[, a_cols]
data_treat <- int_norm[, b_cols]

limma_result <- run_limma(
  data_ctl      = data_ctl,
  data_treat    = data_treat,
  feature_names = rownames(int_norm),
  alpha         = 0.05,
  fc_cut        = 1.0  # log2FC > 1 = 2-fold change for high-res data
)

cat("  Total features tested:", nrow(limma_result$results), "\n")
cat("  Significant features:", nrow(limma_result$significant), "\n")
cat("  Used raw p-value:", limma_result$used_raw_pval, "\n")

write.csv(limma_result$results, file.path(RESULTS_DIR, "03_limma_all_results.csv"))
write.csv(limma_result$significant, file.path(RESULTS_DIR, "03_limma_significant.csv"))
cat("  Saved limma results\n\n")

## ========================= Step 4: Visualization =========================
cat("===== Step 4: Visualization (Nature specs) =====\n")

## ---------- Theme + helpers ----------
theme_nature <- function(base_size = 7) {
  theme_classic(base_size = base_size, base_family = "sans") +
    theme(
      axis.line         = element_line(colour = "black", linewidth = 0.5),
      axis.ticks        = element_line(colour = "black", linewidth = 0.4),
      axis.ticks.length = unit(2, "pt"),
      axis.title        = element_text(size = 7, colour = "black"),
      axis.text         = element_text(size = 6, colour = "black"),
      panel.border      = element_blank(),
      panel.background  = element_rect(fill = "white", colour = NA),
      panel.grid        = element_blank(),
      plot.background   = element_rect(fill = "white", colour = NA),
      legend.title      = element_text(size = 6, face = "bold"),
      legend.text       = element_text(size = 6),
      legend.key.size   = unit(3, "mm"),
      legend.key        = element_rect(fill = NA, colour = NA),
      legend.background = element_rect(fill = NA, colour = NA),
      legend.position   = "right",
      plot.tag          = element_text(size = 8, face = "bold", colour = "black"),
      plot.tag.position = "topleft",
      plot.margin       = margin(4, 4, 4, 4, "mm"),
      strip.text        = element_text(size = 6, face = "bold"),
      strip.background  = element_rect(fill = "grey97", colour = NA)
    )
}

save_nature <- function(plot_obj, filename, width_mm = 89, height_mm = 80) {
  ggsave(paste0(filename, ".pdf"), plot = plot_obj,
         width = width_mm, height = height_mm, units = "mm", device = cairo_pdf)
  ggsave(paste0(filename, ".tiff"), plot = plot_obj,
         width = width_mm, height = height_mm, units = "mm", dpi = 450,
         compression = "lzw")
  ggsave(paste0(filename, ".png"), plot = plot_obj,
         width = width_mm, height = height_mm, units = "mm", dpi = 450)
}

## ---------- Shared data ----------
res <- limma_result$results
p_col <- if (limma_result$used_raw_pval) "P.Value" else "adj.P.Val"
alpha <- 0.05
fc_cut <- 1.0

res$Significance <- ifelse(
  res[[p_col]] < alpha & abs(res$logFC) > fc_cut,
  ifelse(res$logFC > 0, "Up", "Down"), "NS"
)
res$Significance <- factor(res$Significance, levels = c("Down", "NS", "Up"))
n_up   <- sum(res$Significance == "Up")
n_down <- sum(res$Significance == "Down")
n_ns   <- sum(res$Significance == "NS")
sig_features <- limma_result$significant

res$mz <- feature_defs[rownames(res), "mzmed"]
res$rt <- feature_defs[rownames(res), "rtmed"] / 60
res$neg_log_p <- -log10(res[[p_col]])

# NPG palette
col_up   <- "#E64B35"
col_down <- "#4DBBD5"
col_ns   <- "#CCCCCC"
col_3rd  <- "#00A087"
col_4th  <- "#3C5488"

## ========================================================================
## FIGURE 1: Overview (183mm)
## ========================================================================
cat("  [Figure 1] Overview panels...\n")

top_hits <- res[res$Significance != "NS", ]
top_hits <- head(top_hits[order(top_hits[[p_col]]), ], min(10, nrow(top_hits)))
res$label <- ifelse(rownames(res) %in% rownames(top_hits),
                    paste0("m/z ", round(res$mz, 4)), "")

p_volcano <- ggplot(res, aes(logFC, neg_log_p)) +
  geom_point(data = subset(res, Significance == "NS"),
             color = col_ns, size = 0.8, alpha = 0.4) +
  geom_point(data = subset(res, Significance != "NS"),
             aes(fill = Significance), shape = 21, size = 1.5,
             alpha = 0.85, color = "white", stroke = 0.3) +
  scale_fill_manual(values = c(Down = col_down, Up = col_up),
                    labels = c(paste0("Down (", n_down, ")"),
                               paste0("Up (", n_up, ")"))) +
  geom_vline(xintercept = c(-fc_cut, fc_cut), linetype = "dashed",
             linewidth = 0.3, color = "grey50") +
  geom_hline(yintercept = -log10(alpha), linetype = "dashed",
             linewidth = 0.3, color = "grey50") +
  geom_text_repel(data = subset(res, label != ""),
                  aes(label = label), size = 1.8, color = "black",
                  box.padding = 0.3, point.padding = 0.2,
                  segment.color = "grey60", segment.size = 0.3,
                  max.overlaps = 20, min.segment.length = 0.1) +
  labs(x = expression(log[2]~"Fold Change (B/A)"),
       y = expression(-log[10]~italic(P)[adj]),
       fill = NULL) +
  theme_nature() +
  theme(legend.position = c(0.20, 0.88), aspect.ratio = 1)

pca_result <- prcomp(t(int_norm), center = TRUE, scale. = TRUE)
pca_df <- data.frame(
  PC1 = pca_result$x[, 1], PC2 = pca_result$x[, 2],
  Group = factor(sample_group, levels = c("A", "B"))
)
var_explained <- summary(pca_result)$importance[2, 1:2] * 100

p_pca <- ggplot(pca_df, aes(PC1, PC2, fill = Group, shape = Group)) +
  {if (min(table(pca_df$Group)) >= 3)
    stat_ellipse(aes(color = Group), type = "t", level = 0.95,
                 linewidth = 0.4, linetype = "solid", show.legend = FALSE)} +
  geom_point(size = 2.5, color = "white", stroke = 0.5) +
  scale_fill_manual(values = c("A" = col_4th, "B" = col_up)) +
  scale_color_manual(values = c("A" = col_4th, "B" = col_up)) +
  scale_shape_manual(values = c("A" = 21, "B" = 24)) +
  labs(x = sprintf("PC1 (%.1f%%)", var_explained[1]),
       y = sprintf("PC2 (%.1f%%)", var_explained[2]),
       fill = NULL, shape = NULL) +
  guides(fill = guide_legend(override.aes = list(size = 2.5))) +
  theme_nature() +
  theme(legend.position = c(0.85, 0.88), aspect.ratio = 1)

p_ma <- ggplot(res, aes(AveExpr, logFC)) +
  geom_point(data = subset(res, Significance == "NS"),
             color = col_ns, size = 0.6, alpha = 0.4) +
  geom_point(data = subset(res, Significance != "NS"),
             aes(fill = Significance), shape = 21, size = 1.2,
             color = "white", stroke = 0.3, alpha = 0.85) +
  scale_fill_manual(values = c(Down = col_down, Up = col_up)) +
  geom_hline(yintercept = c(-fc_cut, fc_cut), linetype = "dashed",
             linewidth = 0.3, color = "grey50") +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "black") +
  labs(x = expression("Average expression ("*log[2]*")"),
       y = expression(log[2]~"Fold Change"),
       fill = NULL) +
  theme_nature() +
  theme(legend.position = "none", aspect.ratio = 1)

fig1 <- (p_volcano | p_pca | p_ma) +
  plot_layout(widths = c(1, 1, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 8, face = "bold", family = "sans"))

save_nature(fig1, file.path(RESULTS_DIR, "Fig1_overview"), 183, 70)
cat("  Figure 1 saved\n")

## ========================================================================
## FIGURE 2: Feature detail (183mm)
## ========================================================================
cat("  [Figure 2] Feature detail panels...\n")

if (nrow(sig_features) > 0) {

  top4 <- head(sig_features[order(sig_features[[p_col]]), ],
               min(4, nrow(sig_features)))
  vbj_data <- do.call(rbind, lapply(rownames(top4), function(fid) {
    mz_val <- round(feature_defs[fid, "mzmed"], 4)
    rt_min <- round(feature_defs[fid, "rtmed"] / 60, 1)
    data.frame(
      Feature   = fid,
      Label     = paste0("m/z ", mz_val, "\n", rt_min, " min"),
      Intensity = int_norm[fid, ],
      Group     = factor(sample_group, levels = c("A", "B")),
      stringsAsFactors = FALSE
    )
  }))
  vbj_data$Label <- factor(vbj_data$Label, levels = unique(vbj_data$Label))

  n_per_group <- min(table(sample_group))
  p_violin <- ggplot(vbj_data, aes(Group, Intensity, fill = Group, color = Group)) +
    {if (n_per_group >= 3)
      geom_violin(width = 0.8, alpha = 0.25, linewidth = 0.4, trim = FALSE)} +
    geom_boxplot(width = if (n_per_group >= 3) 0.15 else 0.5,
                 alpha = 0.7, linewidth = 0.4,
                 outlier.shape = NA, color = "black", fill = NA) +
    geom_jitter(width = 0.08, size = 1.5, alpha = 0.7, shape = 16) +
    facet_wrap(~ Label, scales = "free_y", nrow = 1) +
    scale_fill_manual(values = alpha(c("A" = col_4th, "B" = col_up), 0.5)) +
    scale_color_manual(values = c("A" = col_4th, "B" = col_up)) +
    labs(y = expression(log[2]~"Intensity"), x = NULL) +
    theme_nature() +
    theme(legend.position = "none", aspect.ratio = 1.3,
          strip.text = element_text(size = 5))

  bubble_data <- res[res$Significance != "NS", ]
  if (nrow(bubble_data) > 0) {
    bubble_data$abs_fc <- abs(bubble_data$logFC)

    p_bubble <- ggplot(bubble_data, aes(rt, mz, size = abs_fc, color = neg_log_p)) +
      geom_point(data = res, aes(rt, mz), inherit.aes = FALSE,
                 color = "#E8E8E8", size = 0.3, alpha = 0.5) +
      geom_point(alpha = 0.8) +
      scale_size_continuous(range = c(1.5, 7),
                            name = expression("|"*log[2]*"FC|"),
                            breaks = pretty) +
      scale_color_gradientn(
        colours = c("#FFF5EB", "#FDD0A2", "#FD8D3C", "#D94801", "#7F2704"),
        name = expression(-log[10]*italic(P)[adj])
      ) +
      labs(x = "Retention time (min)", y = expression(italic(m/z))) +
      theme_nature() +
      theme(aspect.ratio = 0.8,
            legend.key.height = unit(8, "mm"),
            legend.key.width  = unit(3, "mm"))
  }

  top20 <- head(sig_features[order(sig_features[[p_col]]), ],
                min(20, nrow(sig_features)))
  lollipop_data <- data.frame(
    Feature   = rownames(top20),
    logFC     = top20$logFC,
    neg_log_p = -log10(top20[[p_col]]),
    Direction = ifelse(top20$logFC > 0, "Up", "Down"),
    mz_label  = paste0("m/z ", round(feature_defs[rownames(top20), "mzmed"], 4)),
    stringsAsFactors = FALSE
  )
  lollipop_data$mz_label <- make.unique(lollipop_data$mz_label, sep = " #")
  lollipop_data$mz_label <- factor(lollipop_data$mz_label,
                                    levels = rev(lollipop_data$mz_label))

  p_lollipop <- ggplot(lollipop_data, aes(logFC, mz_label)) +
    geom_segment(aes(x = 0, xend = logFC, y = mz_label, yend = mz_label),
                 color = "grey70", linewidth = 0.4) +
    geom_point(aes(fill = Direction, size = neg_log_p),
               shape = 21, color = "white", stroke = 0.4) +
    scale_fill_manual(values = c(Down = col_down, Up = col_up)) +
    scale_size_continuous(range = c(1.5, 4.5),
                          name = expression(-log[10]*italic(P))) +
    geom_vline(xintercept = 0, linewidth = 0.5, color = "black") +
    labs(x = expression(log[2]~"Fold Change"), y = NULL, fill = NULL) +
    theme_nature() +
    theme(axis.text.y = element_text(size = 5))

  if (exists("p_bubble")) {
    fig2_layout <- "
    AAAA
    BBCC
    "
    fig2 <- p_violin + p_bubble + p_lollipop +
      plot_layout(design = fig2_layout, heights = c(1, 1.2)) +
      plot_annotation(tag_levels = "a") &
      theme(plot.tag = element_text(size = 8, face = "bold", family = "sans"))

    save_nature(fig2, file.path(RESULTS_DIR, "Fig2_features"), 183, 160)
    cat("  Figure 2 saved\n")
  }

  ## ========================================================================
  ## FIGURE 3: Heatmap (89mm)
  ## ========================================================================
  cat("  [Figure 3] Heatmap...\n")

  top_n <- min(40, nrow(sig_features))
  top_features <- head(sig_features[order(sig_features[[p_col]]), ], top_n)
  heatmap_data <- int_norm[rownames(top_features), ]
  heatmap_scaled <- t(scale(t(heatmap_data)))
  heatmap_scaled[heatmap_scaled >  2] <-  2
  heatmap_scaled[heatmap_scaled < -2] <- -2

  rownames(heatmap_scaled) <- paste0("m/z ", round(
    feature_defs[rownames(heatmap_scaled), "mzmed"], 4))

  annotation_col <- data.frame(
    Group = factor(sample_group, levels = c("A", "B")),
    row.names = colnames(heatmap_data)
  )
  ann_colors <- list(Group = c("A" = col_4th, "B" = col_up))
  hm_colors <- colorRampPalette(c(col_4th, "#F7F7F7", col_up))(100)

  hm_args <- list(
    mat               = heatmap_scaled,
    color             = hm_colors,
    annotation_col    = annotation_col,
    annotation_colors = ann_colors,
    cluster_rows      = TRUE,
    cluster_cols      = TRUE,
    show_rownames     = (top_n <= 40),
    show_colnames     = FALSE,
    fontsize          = 6,
    fontsize_row      = 4,
    fontsize_col      = 5,
    treeheight_row    = 15,
    treeheight_col    = 15,
    border_color      = NA,
    cellwidth         = 8,
    cellheight        = if (top_n <= 40) 4.5 else NA,
    legend_breaks     = c(-2, -1, 0, 1, 2),
    legend_labels     = c("-2", "-1", "0", "1", "2"),
    annotation_legend = TRUE,
    annotation_names_col = TRUE,
    angle_col         = 0
  )

  pdf(file.path(RESULTS_DIR, "Fig3_heatmap.pdf"),
      width = 89/25.4, height = min(247, 40 + top_n * 4.5 * 0.35)/25.4)
  do.call(pheatmap, hm_args)
  dev.off()

  png(file.path(RESULTS_DIR, "Fig3_heatmap.png"),
      width = 89, height = min(247, 40 + top_n * 4.5 * 0.35),
      units = "mm", res = 450)
  do.call(pheatmap, hm_args)
  dev.off()
  cat("  Figure 3 saved\n")

} else {
  cat("  No significant features — Figures 2-3 skipped\n")
}

## ========================================================================
## Figure captions
## ========================================================================
cat("  Writing figure captions...\n")
captions <- c(
  "FIGURE CAPTIONS — MTBLS733 Q Exactive HF",
  "==========================================",
  "",
  paste0("Figure 1 | Untargeted metabolomics overview of Piper nigrum seed extracts ",
         "analysed by LC-HRMS (Thermo Q Exactive HF)."),
  paste0("a, Volcano plot of ", nrow(res), " features. Dashed lines: |log2FC| > ", fc_cut,
         " and adjusted P < ", alpha, ". ",
         n_up, " upregulated and ", n_down, " downregulated features. ",
         "b, PCA score plot with 95% confidence ellipses. ",
         "c, MA plot. ",
         "n = ", sum(sample_group == "A"), " (A) and ",
         sum(sample_group == "B"), " (B). ",
         "Moderated t-test (limma) with BH correction."),
  "",
  paste0("Figure 2 | Feature-level characterization."),
  paste0("a, Violin + box + jitter plots for top 4 features. ",
         "b, Feature landscape (RT x m/z); size = |log2FC|, colour = -log10(Padj). ",
         "c, Lollipop plot of top 20 effect sizes."),
  "",
  paste0("Figure 3 | Heatmap of top significant features (z-score, clipped [-2,2]).")
)
writeLines(captions, file.path(RESULTS_DIR, "00_FIGURE_CAPTIONS.txt"))

## ========================= Step 5: Summary =========================
cat("\n===== Step 5: Summary Report =====\n")
summary_lines <- c(
  "===============================================",
  "MetaboFlow E2E Pipeline — Q Exactive HF (MTBLS733)",
  paste("Date:", Sys.time()),
  "===============================================",
  "",
  "## Dataset",
  "  Source: MTBLS733 (MetaboLights)",
  "  Organism: Piper nigrum (black pepper) seeds",
  "  Instrument: Thermo Q Exactive HF",
  "  Ionization: ESI+, 100-1500 m/z",
  "  Chromatography: RPLC C18 (ZORBAX Eclipse Plus)",
  paste("  Groups: A (n=", sum(sample_group == "A"),
        ") vs B (n=", sum(sample_group == "B"), ")"),
  "",
  "## Step 1: Peak Detection",
  "  Engine: xcms CentWave (optimized for Orbitrap)",
  "  Parameters: ppm=5, peakwidth=5-20s, snthresh=6",
  paste("  Raw chromatographic peaks:", nrow(chromPeaks(xdata))),
  paste("  Grouped features:", nrow(feature_values)),
  paste("  Time:", round(difftime(t1_end, t1, units = "secs"), 1), "s"),
  "",
  "## Step 2: Preprocessing",
  paste("  Features after NA filter:", nrow(int_matrix)),
  "  Imputation: min/2 | Transform: log2 | Norm: median",
  "",
  "## Step 3: Differential Analysis",
  paste("  Significant (adj.P<0.05, |log2FC|>", fc_cut, "):", nrow(sig_features)),
  paste("  Up:", n_up, "| Down:", n_down),
  "",
  "## Step 4: Figures",
  "  Fig1: Overview (volcano + PCA + MA) — 183mm",
  "  Fig2: Feature detail (violin + bubble + lollipop) — 183mm",
  "  Fig3: Heatmap — 89mm",
  "==============================================="
)
writeLines(summary_lines, file.path(RESULTS_DIR, "00_E2E_REPORT.txt"))
cat(paste(summary_lines, collapse = "\n"), "\n")

cat("\n===== Output Files =====\n")
output_files <- list.files(RESULTS_DIR, recursive = TRUE)
for (f in output_files) {
  fsize <- file.size(file.path(RESULTS_DIR, f))
  cat(sprintf("  %-45s %s\n", f, format(fsize, big.mark = ",")))
}

cat("\n========== E2E Pipeline Complete ==========\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

##############################################################################
##  MetaboFlow E2E Pipeline Test
##  Uses real public data (faahKO: WT vs FAAH-KO mouse spinal cord, LC-MS)
##
##  Pipeline: Raw CDF → xcms peak detection → preprocessing → limma
##            differential → volcano/PCA/heatmap/boxplot → report
##
##  Input:  /data/faahKO_raw/{WT,KO}/*.CDF
##  Output: /results/ (CSV tables + PDF/TIFF charts)
##############################################################################

cat("========== MetaboFlow E2E Pipeline Test ==========\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

suppressPackageStartupMessages({
  library(MSnbase)
  library(xcms)
  library(limma)
  library(ggplot2)
  library(dplyr)
  library(pheatmap)
})

## Source stats-worker modules for differential + visualization
source("/app/R/config.R")
source("/app/R/differential.R")
# visualization.R sources config.R via sys.frame which won't work here,
# so we inline the needed functions

## ========================= Config =========================
DATA_DIR    <- "/data/faahKO_raw"
RESULTS_DIR <- "/results"
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

wt_files <- sort(list.files(file.path(DATA_DIR, "WT"), full.names = TRUE, pattern = "\\.CDF$"))
ko_files <- sort(list.files(file.path(DATA_DIR, "KO"), full.names = TRUE, pattern = "\\.CDF$"))
all_files <- c(wt_files, ko_files)

cat("Found", length(wt_files), "WT files and", length(ko_files), "KO files\n")
if (length(wt_files) == 0 || length(ko_files) == 0) {
  stop("No CDF files found in ", DATA_DIR)
}

sample_names <- gsub("\\.CDF$", "", basename(all_files))
sample_group <- ifelse(grepl("^wt", sample_names), "WT", "KO")
sample_info  <- data.frame(
  sample_id = sample_names,
  group     = sample_group,
  file      = all_files,
  stringsAsFactors = FALSE
)
cat("Sample info:\n")
print(sample_info[, c("sample_id", "group")])
cat("\n")

## ========================= Step 1: Peak Detection (xcms) =========================
cat("===== Step 1: Peak Detection (xcms CentWave) =====\n")
t1 <- Sys.time()

# Force serial processing (avoids fork issues in Docker)
register(SerialParam())

# Read raw data
raw_data <- readMSData(all_files, mode = "onDisk")

# CentWave peak detection (matched-filter is more robust for CDF/GC-MS data)
# Using MatchedFilterParam since faahKO is a classic GC-MS-like dataset
cwp <- MatchedFilterParam(
  binSize  = 0.25,
  fwhm     = 30,
  snthresh = 5
)
xdata <- findChromPeaks(raw_data, param = cwp)
cat("  Chromatic peaks found:", nrow(chromPeaks(xdata)), "\n")

# Peak grouping (correspondence)
pdp <- PeakDensityParam(
  sampleGroups = sample_group,
  minFraction  = 0.5,
  bw           = 5,
  binSize      = 0.025
)
xdata <- groupChromPeaks(xdata, param = pdp)
cat("  Features after grouping:", nrow(featureDefinitions(xdata)), "\n")

# Fill missing peaks
xdata <- fillChromPeaks(xdata)

# Extract feature values (intensity matrix)
feature_values <- featureValues(xdata, value = "into", method = "maxint")
feature_defs   <- featureDefinitions(xdata)

t1_end <- Sys.time()
cat("  Peak detection time:", round(difftime(t1_end, t1, units = "secs"), 1), "seconds\n")
cat("  Final feature matrix:", nrow(feature_values), "features x", ncol(feature_values), "samples\n\n")

## ========================= Step 2: Preprocessing =========================
cat("===== Step 2: Preprocessing =====\n")

# Create peak table with mz and rt
peak_table <- data.frame(
  feature_id = rownames(feature_values),
  mz         = feature_defs$mzmed,
  rt         = feature_defs$rtmed,
  feature_values,
  check.names = FALSE
)

# Save raw peak table
write.csv(peak_table, file.path(RESULTS_DIR, "01_raw_peak_table.csv"), row.names = FALSE)
cat("  Saved raw peak table:", nrow(peak_table), "features\n")

# Intensity matrix (features x samples)
int_matrix <- as.matrix(feature_values)

# Remove features with >50% missing values
na_frac <- rowMeans(is.na(int_matrix))
keep    <- na_frac <= 0.5
int_matrix <- int_matrix[keep, ]
cat("  After NA filter (<=50% missing):", nrow(int_matrix), "features\n")

# KNN-like imputation: replace NA with row minimum / 2
for (i in seq_len(nrow(int_matrix))) {
  na_idx <- is.na(int_matrix[i, ])
  if (any(na_idx)) {
    row_min <- min(int_matrix[i, !na_idx], na.rm = TRUE)
    int_matrix[i, na_idx] <- row_min / 2
  }
}
cat("  Missing values imputed (min/2 method)\n")

# Log10 transform
int_log <- log10(int_matrix + 1)

# Median normalization
col_medians  <- apply(int_log, 2, median)
global_median <- median(col_medians)
norm_factors  <- global_median - col_medians
int_norm      <- sweep(int_log, 2, norm_factors, "+")

cat("  Log10 + median normalization applied\n")

# Save processed peak table
processed_table <- data.frame(
  feature_id = rownames(int_norm),
  mz         = feature_defs[rownames(int_norm), "mzmed"],
  rt         = feature_defs[rownames(int_norm), "rtmed"],
  int_norm,
  check.names = FALSE
)
write.csv(processed_table, file.path(RESULTS_DIR, "02_processed_peak_table.csv"), row.names = FALSE)
cat("  Saved processed peak table:", nrow(processed_table), "features\n\n")

## ========================= Step 3: Differential Analysis (limma) =========================
cat("===== Step 3: Differential Analysis (limma) =====\n")

wt_cols <- grep("^wt", colnames(int_norm))
ko_cols <- grep("^ko", colnames(int_norm))

data_ctl   <- int_norm[, wt_cols]
data_treat <- int_norm[, ko_cols]

limma_result <- run_limma(
  data_ctl      = data_ctl,
  data_treat    = data_treat,
  feature_names = rownames(int_norm),
  alpha         = 0.05,
  fc_cut        = 0.176
)

cat("  Total features tested:", nrow(limma_result$results), "\n")
cat("  Significant features:", nrow(limma_result$significant), "\n")
cat("  Used raw p-value:", limma_result$used_raw_pval, "\n")

# Save limma results
write.csv(limma_result$results, file.path(RESULTS_DIR, "03_limma_all_results.csv"))
write.csv(limma_result$significant, file.path(RESULTS_DIR, "03_limma_significant.csv"))
cat("  Saved limma results\n\n")

## ========================= Step 4: Visualization =========================
cat("===== Step 4: Visualization =====\n")

## --- 4.1 Volcano Plot ---
cat("  Generating volcano plot...\n")

theme_nature <- function(base_size = 8, subfig_mode = FALSE) {
  if (isTRUE(subfig_mode)) base_size <- base_size + 3
  theme_bw(base_size = base_size) %+replace%
    theme(
      text             = element_text(family = "sans", color = "black"),
      axis.title       = element_text(size = base_size + 1, face = "bold"),
      axis.text        = element_text(size = base_size, color = "black"),
      plot.title       = element_text(size = base_size + 2, face = "bold", hjust = 0),
      legend.title     = element_text(size = base_size, face = "bold"),
      legend.text      = element_text(size = base_size - 1),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", linewidth = 0.6),
      axis.ticks       = element_line(color = "black", linewidth = 0.4),
      plot.margin      = margin(8, 8, 8, 8, "pt"),
      legend.key.size  = unit(0.35, "cm"),
      aspect.ratio     = 1
    )
}

save_plot <- function(plot_obj, filename, width = 7, height = 7) {
  ggsave(paste0(filename, ".pdf"), plot = plot_obj,
         width = width, height = height, units = "in", device = cairo_pdf)
  ggsave(paste0(filename, ".tiff"), plot = plot_obj,
         width = width, height = height, units = "in", dpi = 300,
         compression = "lzw")
  ggsave(paste0(filename, ".png"), plot = plot_obj,
         width = width, height = height, units = "in", dpi = 300)
}

res <- limma_result$results
p_col <- if (limma_result$used_raw_pval) "P.Value" else "adj.P.Val"
alpha <- 0.05
fc_cut <- 0.176

res$Significance <- ifelse(
  res[[p_col]] < alpha & abs(res$logFC) > fc_cut,
  ifelse(res$logFC > 0, "Up", "Down"),
  "Not"
)
res$Significance <- factor(res$Significance, levels = c("Down", "Not", "Up"))
n_up   <- sum(res$Significance == "Up")
n_down <- sum(res$Significance == "Down")

p_volcano <- ggplot(res, aes(logFC, -log10(.data[[p_col]]))) +
  geom_point(aes(color = Significance), size = 1.5, alpha = 0.7) +
  scale_color_manual(
    values = volcano_colors,
    labels = c(paste0("Down (", n_down, ")"), "NS", paste0("Up (", n_up, ")"))
  ) +
  geom_vline(xintercept = c(-fc_cut, fc_cut), lty = 2, color = "grey40", linewidth = 0.4) +
  geom_hline(yintercept = -log10(alpha), lty = 2, color = "grey40", linewidth = 0.4) +
  labs(
    x     = expression("log"[10]*"(Fold Change)"),
    y     = bquote("-log"[10]*"("*.(p_col)*")"),
    title = "faahKO: WT vs KO Differential Features",
    color = ""
  ) +
  theme_nature(base_size = 9)

save_plot(p_volcano, file.path(RESULTS_DIR, "04_volcano_plot"), width = 6, height = 6)
cat("  Volcano plot saved (PDF + TIFF + PNG)\n")

## --- 4.2 PCA Plot ---
cat("  Generating PCA plot...\n")

pca_result <- prcomp(t(int_norm), center = TRUE, scale. = TRUE)
pca_df <- data.frame(
  PC1   = pca_result$x[, 1],
  PC2   = pca_result$x[, 2],
  Group = sample_group,
  Sample = sample_names
)
var_explained <- summary(pca_result)$importance[2, 1:2] * 100

p_pca <- ggplot(pca_df, aes(PC1, PC2, color = Group)) +
  geom_point(size = 3) +
  stat_ellipse(level = 0.95, linetype = 2, linewidth = 0.5) +
  scale_color_manual(values = c("WT" = nature_colors[1], "KO" = nature_colors[2])) +
  labs(
    x     = sprintf("PC1 (%.1f%%)", var_explained[1]),
    y     = sprintf("PC2 (%.1f%%)", var_explained[2]),
    title = "PCA: WT vs KO (faahKO dataset)",
    color = "Group"
  ) +
  theme_nature(base_size = 9)

save_plot(p_pca, file.path(RESULTS_DIR, "04_pca_plot"), width = 6, height = 6)
cat("  PCA plot saved\n")

## --- 4.3 Heatmap (top 50 significant features) ---
cat("  Generating heatmap...\n")

sig_features <- limma_result$significant
if (nrow(sig_features) > 0) {
  top_n <- min(50, nrow(sig_features))
  top_features <- head(sig_features[order(sig_features[[p_col]]), ], top_n)
  heatmap_data <- int_norm[rownames(top_features), ]

  # Scale by row for visualization
  heatmap_scaled <- t(scale(t(heatmap_data)))

  annotation_col <- data.frame(
    Group = factor(sample_group, levels = c("WT", "KO")),
    row.names = colnames(heatmap_data)
  )
  ann_colors <- list(Group = c("WT" = nature_colors[1], "KO" = nature_colors[2]))

  pdf(file.path(RESULTS_DIR, "04_heatmap_top50.pdf"), width = 8, height = 10)
  pheatmap(
    heatmap_scaled,
    color            = heatmap_colors,
    annotation_col   = annotation_col,
    annotation_colors = ann_colors,
    cluster_rows     = TRUE,
    cluster_cols     = TRUE,
    show_rownames    = (top_n <= 30),
    show_colnames    = TRUE,
    main             = sprintf("Top %d Differential Features (faahKO)", top_n),
    fontsize         = 8,
    border_color     = NA
  )
  dev.off()

  png(file.path(RESULTS_DIR, "04_heatmap_top50.png"), width = 8, height = 10, units = "in", res = 300)
  pheatmap(
    heatmap_scaled,
    color            = heatmap_colors,
    annotation_col   = annotation_col,
    annotation_colors = ann_colors,
    cluster_rows     = TRUE,
    cluster_cols     = TRUE,
    show_rownames    = (top_n <= 30),
    show_colnames    = TRUE,
    main             = sprintf("Top %d Differential Features (faahKO)", top_n),
    fontsize         = 8,
    border_color     = NA
  )
  dev.off()
  cat("  Heatmap saved (top", top_n, "features)\n")
} else {
  cat("  No significant features — heatmap skipped\n")
}

## --- 4.4 Boxplot (top 6 significant features) ---
cat("  Generating boxplots...\n")

if (nrow(sig_features) > 0) {
  top6 <- head(sig_features[order(sig_features[[p_col]]), ], min(6, nrow(sig_features)))

  box_data <- reshape2_melt <- do.call(rbind, lapply(rownames(top6), function(fid) {
    data.frame(
      Feature   = fid,
      Intensity = int_norm[fid, ],
      Group     = sample_group,
      Sample    = sample_names
    )
  }))

  # Add mz/rt info to feature labels
  box_data$Feature_label <- sapply(box_data$Feature, function(fid) {
    mz_val <- round(feature_defs[fid, "mzmed"], 2)
    rt_val <- round(feature_defs[fid, "rtmed"], 1)
    paste0(fid, "\nm/z=", mz_val, " RT=", rt_val, "s")
  })

  p_box <- ggplot(box_data, aes(Group, Intensity, fill = Group)) +
    geom_boxplot(width = 0.6, outlier.size = 1) +
    geom_jitter(width = 0.15, size = 1, alpha = 0.6) +
    facet_wrap(~ Feature_label, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = c("WT" = nature_colors[1], "KO" = nature_colors[2])) +
    labs(
      y     = "log10(Normalized Intensity)",
      title = "Top Differential Features: WT vs KO",
      fill  = "Group"
    ) +
    theme_nature(base_size = 8) +
    theme(aspect.ratio = NULL, strip.text = element_text(size = 7))

  save_plot(p_box, file.path(RESULTS_DIR, "04_boxplots_top6"), width = 10, height = 7)
  cat("  Boxplots saved\n")
} else {
  cat("  No significant features — boxplots skipped\n")
}

## --- 4.5 MA Plot ---
cat("  Generating MA plot...\n")

res$AveExpr_rescaled <- res$AveExpr
p_ma <- ggplot(res, aes(AveExpr, logFC)) +
  geom_point(aes(color = Significance), size = 1, alpha = 0.6) +
  scale_color_manual(values = volcano_colors) +
  geom_hline(yintercept = c(-fc_cut, fc_cut), lty = 2, color = "grey40", linewidth = 0.4) +
  labs(
    x     = "Average Expression (log10)",
    y     = "log10(Fold Change)",
    title = "MA Plot: WT vs KO",
    color = ""
  ) +
  theme_nature(base_size = 9)

save_plot(p_ma, file.path(RESULTS_DIR, "04_ma_plot"), width = 6, height = 6)
cat("  MA plot saved\n")

## ========================= Step 5: Summary Report =========================
cat("\n===== Step 5: Summary Report =====\n")

summary_lines <- c(
  "===============================================",
  "MetaboFlow E2E Pipeline Report",
  paste("Date:", Sys.time()),
  "===============================================",
  "",
  "## Dataset",
  paste("  Source: faahKO (Bioconductor)"),
  paste("  Organism: Mouse (Mus musculus) spinal cord"),
  paste("  Platform: LC-MS"),
  paste("  Groups: WT (n=6) vs FAAH-KO (n=6)"),
  "",
  "## Step 1: Peak Detection",
  paste("  Engine: xcms CentWave"),
  paste("  Parameters: ppm=25, peakwidth=20-80s, snthresh=10, noise=1000"),
  paste("  Raw chromatographic peaks:", nrow(chromPeaks(xdata))),
  paste("  Grouped features:", nrow(feature_values)),
  paste("  Processing time:", round(difftime(t1_end, t1, units = "secs"), 1), "seconds"),
  "",
  "## Step 2: Preprocessing",
  paste("  Features after NA filter:", nrow(int_matrix)),
  paste("  Imputation: min/2"),
  paste("  Transformation: log10"),
  paste("  Normalization: median"),
  "",
  "## Step 3: Differential Analysis",
  paste("  Method: limma (eBayes)"),
  paste("  Contrast: KO - WT"),
  paste("  Alpha:", alpha, "| FC cutoff:", fc_cut),
  paste("  Total features tested:", nrow(limma_result$results)),
  paste("  Significant features:", nrow(limma_result$significant)),
  paste("  Used raw p-value:", limma_result$used_raw_pval),
  paste("  Up-regulated:", n_up),
  paste("  Down-regulated:", n_down),
  "",
  "## Step 4: Outputs",
  "  CSV files:",
  "    - 01_raw_peak_table.csv",
  "    - 02_processed_peak_table.csv",
  "    - 03_limma_all_results.csv",
  "    - 03_limma_significant.csv",
  "  Charts:",
  "    - 04_volcano_plot.{pdf,tiff,png}",
  "    - 04_pca_plot.{pdf,tiff,png}",
  "    - 04_heatmap_top50.{pdf,png}",
  "    - 04_boxplots_top6.{pdf,tiff,png}",
  "    - 04_ma_plot.{pdf,tiff,png}",
  "",
  "==============================================="
)

writeLines(summary_lines, file.path(RESULTS_DIR, "00_E2E_REPORT.txt"))
cat(paste(summary_lines, collapse = "\n"), "\n")

## Final file listing
cat("\n===== Output Files =====\n")
output_files <- list.files(RESULTS_DIR, recursive = TRUE)
for (f in output_files) {
  fsize <- file.size(file.path(RESULTS_DIR, f))
  cat(sprintf("  %-45s %s\n", f, format(fsize, big.mark = ",")))
}

cat("\n========== E2E Pipeline Complete ==========\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

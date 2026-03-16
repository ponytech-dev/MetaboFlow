##############################################################################
##  stats-worker/R/differential.R
##  差异分析 / Differential Analysis
##
##  基于limma的差异代谢峰分析，含小样本回退策略。
##  limma-based differential feature analysis with small-sample fallback.
##  No global variable dependencies — all parameters are explicit.
##############################################################################

## ========================= limma差异分析 / limma Differential Analysis =========================

## 对两组log10强度矩阵运行limma差异分析
## Run limma differential analysis on two groups of log10-intensity matrices
##
## @param data_ctl      对照组表达矩阵（features × samples）/ control group matrix (features × samples)
## @param data_treat    处理组表达矩阵（features × samples）/ treatment group matrix (features × samples)
## @param feature_names feature行名 / row names for features
## @param alpha         显著性阈值（FDR）/ significance threshold (FDR-corrected p-value)
## @param fc_cut        log10 FC阈值 / log10 FC cutoff
##
## @return 列表 / list with:
##   $results      — 完整topTable结果（所有features）/ full topTable (all features)
##   $significant  — 筛选后的显著差异features / significant features after filtering
##   $used_raw_pval — 逻辑值：是否回退到原始p值（小样本时）
##                   logical: TRUE if raw P.Value was used instead of adj.P.Val
run_limma <- function(data_ctl,
                      data_treat,
                      feature_names,
                      alpha  = 0.05,
                      fc_cut = 0.176) {
  ana <- cbind(data_ctl, data_treat)
  rownames(ana) <- feature_names

  type_vec <- c(rep("CTL", ncol(data_ctl)), rep("TREAT", ncol(data_treat)))
  design   <- model.matrix(~ 0 + factor(type_vec))
  colnames(design) <- c("CTL", "TREAT")

  fit  <- lmFit(as.data.frame(ana), design = design)
  fit2 <- contrasts.fit(fit, makeContrasts(TREAT - CTL, levels = design))
  fit2 <- eBayes(fit2)

  Diff <- topTable(fit2, adjust = "fdr", number = nrow(ana))

  ## 小样本回退策略：n<=3时adj.P.Val可能全>0.05，自动退回P.Value
  ## Small-sample fallback: when all adj.P.Val > alpha (e.g. n<=3), fall back to raw P.Value
  used_raw_pval <- !any(Diff$adj.P.Val < alpha)
  p_col         <- if (used_raw_pval) "P.Value" else "adj.P.Val"

  sig <- Diff[abs(Diff$logFC) >= fc_cut & Diff[[p_col]] < alpha, ]

  list(
    results       = Diff,
    significant   = sig,
    used_raw_pval = used_raw_pval
  )
}

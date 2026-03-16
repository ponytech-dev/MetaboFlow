##############################################################################
##  xcms-worker/R/utils.R
##  通用工具函数 / General utility functions for xcms-worker
##
##  提供HMDB ID标准化、非特异性通路过滤和通路图数据准备。
##  Provides HMDB ID normalization, non-specific pathway filtering,
##  and pathway plot data preparation.
##  No global variable dependencies — all parameters are explicit.
##############################################################################

## ========================= HMDB ID标准化 / HMDB ID Normalization =========================

## 将旧版7位HMDB ID转换为11位格式，并去重、去空值
## Convert legacy 7-digit HMDB IDs to 11-digit format; deduplicate and remove NAs/empty
##
## 示例/Example: "HMDB00001" → "HMDB0000001"
##
## @param ids 原始HMDB ID字符向量 / raw HMDB ID character vector (may contain NAs and "")
## @return    标准化后的唯一非空HMDB ID向量 / unique non-empty normalized HMDB ID vector
normalize_hmdb <- function(ids) {
  ids <- ids[!is.na(ids) & ids != ""]
  ids <- ifelse(
    nchar(ids) == 11 & grepl("^HMDB\\d{5}$", ids),
    paste0("HMDB00", substring(ids, 5)),
    ids
  )
  unique(ids)
}


## ========================= 非特异性通路过滤 / Non-specific Pathway Filter =========================

## 默认关键词黑名单（与stats-worker/config.R同步）
## Default keyword blacklist (kept in sync with stats-worker/config.R)
.DEFAULT_NONSPECIFIC_KEYWORDS <- c(
  "Metabolic pathways",
  "Biosynthesis of secondary metabolites",
  "Biosynthesis of amino acids",
  "Carbon metabolism",
  "2-Oxocarboxylic acid metabolism",
  "Biosynthesis of cofactors",
  "ABC transporters",
  "Protein digestion and absorption",
  "Mineral absorption",
  "Aminoacyl-tRNA biosynthesis"
)

## 过滤过于宽泛的非特异性通路（假阳性来源）
## Filter overly broad non-specific pathways (source of false positives)
##
## @param df          通路结果data.frame / pathway result data.frame
## @param keywords    关键词黑名单 / blacklist keyword vector (default: .DEFAULT_NONSPECIFIC_KEYWORDS)
## @param size_cutoff 通路代谢物数上限；超过此值视为非特异性 / pathway size ceiling
## @param enabled     是否启用过滤（FALSE时原样返回两个字段均为df）
##                    whether filtering is active (FALSE = return df unchanged in both slots)
## @param name_col    通路名列名 / column name containing pathway names
## @param size_col    通路大小列名（NULL = 跳过大小过滤）/ pathway size column (NULL = skip size filter)
## @return list(all = 原始显著df, filtered = 过滤后df)
##         list(all = original significant df, filtered = filtered df)
filter_nonspecific <- function(df,
                                keywords     = .DEFAULT_NONSPECIFIC_KEYWORDS,
                                size_cutoff  = 150,
                                enabled      = TRUE,
                                name_col     = "pathway_name",
                                size_col     = NULL) {
  if (nrow(df) == 0) return(list(all = df, filtered = df))

  if (!isTRUE(enabled)) return(list(all = df, filtered = df))

  ## 关键词匹配 / Keyword matching
  blacklist_hit <- sapply(df[[name_col]], function(pw) {
    any(sapply(keywords, function(kw) grepl(kw, pw, ignore.case = TRUE)))
  })

  ## 通路大小过滤 / Size-based filter
  size_hit <- rep(FALSE, nrow(df))
  if (!is.null(size_col) && size_col %in% colnames(df)) {
    size_hit <- df[[size_col]] > size_cutoff
  }

  keep <- !(blacklist_hit | size_hit)
  list(all = df, filtered = df[keep, , drop = FALSE])
}


## ========================= 通路图数据准备 / Pathway Plot Data Preparation =========================

## 按 top_n 截断通路结果（假设调用方已按显著性排序）
## Truncate pathway results to top_n rows (caller is expected to pre-sort by significance)
##
## @param df    通路结果data.frame（已排序）/ pathway result data.frame (pre-sorted)
## @param top_n 最多展示行数；0或NULL = 保留全部 / max rows to keep; 0 or NULL = keep all
## @return      截断后的data.frame / truncated data.frame
prep_pathway_plot <- function(df, top_n = 0) {
  if (nrow(df) == 0) return(df)
  n <- if (!is.null(top_n) && top_n > 0) top_n else nrow(df)
  n <- min(n, nrow(df))
  df[seq_len(n), ]
}

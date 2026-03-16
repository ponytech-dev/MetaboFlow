##############################################################################
##  stats-worker/R/enrichment.R
##  四工作流通路富集分析 / Quad-Workflow Pathway Enrichment Analysis
##
##  WF1: tidymass enrich_hmdb → SMPDB ORA
##  WF2: MetaboAnalystR MSEA  → SMPDB ORA
##  WF3: KEGGREST + Fisher    → KEGG ORA
##  WF4: globaltest           → QEA
##
##  每个工作流独立封装，tryCatch保障优雅降级。
##  Each workflow is independently encapsulated with tryCatch for graceful degradation.
##  Depends on: config.R and visualization.R (must be sourced before this file)
##############################################################################

source(file.path(dirname(sys.frame(1)$ofile), "config.R"))
source(file.path(dirname(sys.frame(1)$ofile), "visualization.R"))


## ========================= 工具函数 / Shared Helpers =========================

## 构建通路点图（共享代码）/ Build enrichment dot-plot (shared across WF1/2/4)
## @param plot_data   data.frame，已按显著性排序 / pre-sorted significant rows
## @param x_col      x轴列名 / x-axis column name
## @param y_col      y轴（通路名）列名 / y-axis (pathway name) column name
## @param size_col   点大小列名 / point size column name (neg_log_p)
## @param color_col  点颜色列名 / point color column name
## @param title      图标题 / plot title
## @param x_label    x轴标签 / x-axis label
## @param subfig_mode 小子图模式 / small sub-figure mode
## @param pathway_gradient 色带向量 / color gradient vector
.make_dot_plot <- function(plot_data, x_col, y_col, size_col, color_col,
                            title, x_label, subfig_mode, pathway_gradient) {
  y_text_size    <- if (isTRUE(subfig_mode)) 9 else 8
  plot_data[[y_col]] <- factor(plot_data[[y_col]], levels = rev(plot_data[[y_col]]))

  ggplot(plot_data, aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_point(aes(size = .data[[size_col]], color = .data[[color_col]])) +
    scale_color_gradientn(colours = pathway_gradient) +
    labs(title = title, x = x_label) +
    theme_nature(base_size = 8, subfig_mode = subfig_mode) +
    theme(aspect.ratio = NULL,
          axis.title.y = element_blank(),
          axis.text.y  = element_text(size = y_text_size)) +
    scale_size(range = c(3, 9))
}


## ========================= WF1: SMPDB (tidymass) =========================

## WF1 SMPDB通路富集分析（tidymass enrich_hmdb ORA）
## WF1 SMPDB pathway enrichment via tidymass enrich_hmdb (ORA)
##
## @param hmdb_ids    标准化后的HMDB ID向量 / normalized HMDB ID vector
## @param prefix      输出文件前缀（含完整路径）/ output file prefix (full path)
## @param output_dir  输出目录路径 / output directory path
## @param params      参数列表 / parameter list containing:
##   $alpha              显著性阈值 / significance threshold
##   $top_n_pathways     图中最多展示通路数（0=全部）
##   $filter_nonspecific 是否过滤非特异性通路 / filter non-specific pathways
##   $pathway_fig_w      图宽(英寸) / figure width (inches)
##   $pathway_fig_h      图高(英寸) / figure height (inches)
##   $subfig_mode        小子图字体放大模式 / small sub-figure mode
##   $nonspecific_keywords  关键词黑名单 / blacklist keywords vector
##   $nonspecific_size_cutoff  通路大小阈值 / pathway size cutoff
##
## @return 不可见地返回结果列表 / invisibly returns list(all, filtered) or NULL on skip/error
run_wf1_smpdb <- function(hmdb_ids, prefix, output_dir, params) {
  cat("  WF1: SMPDB...")

  if (!requireNamespace("tidymass", quietly = TRUE)) {
    cat(" 跳过/skipped (tidymass未安装/not installed)\n")
    return(invisible(NULL))
  }
  if (length(hmdb_ids) < 3) {
    cat(" 跳过/skipped (HMDB IDs不足3个/fewer than 3)\n")
    return(invisible(NULL))
  }

  tryCatch({
    res1 <- tidymass::enrich_hmdb(
      query_id          = hmdb_ids,
      query_type        = "compound",
      id_type           = "HMDB",
      pathway_database  = hmdb_pathway,
      only_primary_pathway = TRUE,
      p_cutoff          = 0.99,
      p_adjust_method   = "BH"
    )
    pw1 <- res1@result
    pw1 <- pw1[pw1$p_value < 0.05 &
               pw1$pathway_class == "Metabolic;primary_pathway", ]
    pw1 <- dplyr::arrange(pw1, dplyr::desc(mapped_number))

    ## 过滤非特异性通路 / Filter non-specific pathways
    pw1_filt <- filter_nonspecific(
      pw1,
      keywords     = params$nonspecific_keywords,
      size_cutoff  = params$nonspecific_size_cutoff,
      enabled      = isTRUE(params$filter_nonspecific),
      name_col     = "pathway_name",
      size_col     = "all_number"
    )

    ## 写出结果 / Write results
    openxlsx::write.xlsx(pw1_filt$all,
                         file.path(output_dir, paste0("smpdb_", prefix, ".xlsx")))
    if (nrow(pw1_filt$filtered) < nrow(pw1_filt$all)) {
      openxlsx::write.xlsx(pw1_filt$filtered,
                           file.path(output_dir, paste0("smpdb_", prefix, "_filtered.xlsx")))
    }

    ## 绘图 / Plot
    pw1_plot_data <- pw1_filt$filtered
    if (nrow(pw1_plot_data) > 0) {
      pw1_plot_data$neg_log_p <- -log10(pw1_plot_data$p_value)
      pw_plot <- .prep_pathway_plot_internal(pw1_plot_data, params$top_n_pathways)

      p_wf1 <- .make_dot_plot(
        plot_data        = pw_plot,
        x_col            = "mapped_number",
        y_col            = "pathway_name",
        size_col         = "neg_log_p",
        color_col        = "mapped_number",
        title            = "SMPDB Pathway Enrichment (WF1-ORA)",
        x_label          = "Mapped compounds",
        subfig_mode      = params$subfig_mode,
        pathway_gradient = params$pathway_gradient
      )
      save_nature_plot(p_wf1,
                       file.path(output_dir, paste0("smpdb_", prefix)),
                       width  = params$pathway_fig_w,
                       height = params$pathway_fig_h)
    }

    cat(" 完成/done (", nrow(pw1_filt$all), "全部/all,",
        nrow(pw1_filt$filtered), "过滤后/filtered)\n")
    invisible(pw1_filt)
  }, error = function(e) {
    cat(" 失败/failed:", conditionMessage(e), "\n")
    invisible(NULL)
  })
}


## ========================= WF2: MSEA (MetaboAnalystR) =========================

## WF2 MSEA代谢物集富集分析（MetaboAnalystR ORA）
## WF2 Metabolite Set Enrichment Analysis via MetaboAnalystR (ORA)
##
## @param hmdb_ids   标准化后的HMDB ID向量 / normalized HMDB ID vector
## @param prefix     输出文件前缀 / output file prefix
## @param output_dir 输出目录 / output directory
## @param params     参数列表（同WF1，另含 $organism 物种代码）/ parameter list
run_wf2_msea <- function(hmdb_ids, prefix, output_dir, params) {
  cat("  WF2: MSEA...")

  if (!requireNamespace("MetaboAnalystR", quietly = TRUE)) {
    cat(" 跳过/skipped (MetaboAnalystR未安装/not installed)\n")
    return(invisible(NULL))
  }
  if (length(hmdb_ids) < 3) {
    cat(" 跳过/skipped (HMDB IDs不足3个/fewer than 3)\n")
    return(invisible(NULL))
  }

  tryCatch({
    mSet <- MetaboAnalystR::InitDataObjects("conc", "msetora", FALSE, default.dpi = 72)
    mSet <- MetaboAnalystR::Setup.MapData(mSet, hmdb_ids)
    mSet <- MetaboAnalystR::CrossReferencing(mSet, "hmdb")
    mSet <- MetaboAnalystR::CreateMappingResultTable(mSet)
    mSet <- MetaboAnalystR::SetMetabolomeFilter(mSet, FALSE)
    mSet <- MetaboAnalystR::SetCurrentMsetLib(mSet, "smpdb_pathway", 0)
    mSet <- MetaboAnalystR::CalculateHyperScore(mSet)

    if (is.null(mSet$analSet$ora.mat)) {
      cat(" 无结果/no results\n")
      return(invisible(NULL))
    }

    msea_res           <- as.data.frame(mSet$analSet$ora.mat)
    msea_res$pathway   <- rownames(msea_res)
    msea_res           <- msea_res[order(msea_res[, "Raw p"]), ]

    ## 推断列名兼容不同版本 / Infer column names for compatibility across versions
    total_col <- if ("Total" %in% colnames(msea_res)) "Total" else
                 if ("total" %in% colnames(msea_res)) "total" else NULL

    msea_filt <- filter_nonspecific(
      msea_res,
      keywords    = params$nonspecific_keywords,
      size_cutoff = params$nonspecific_size_cutoff,
      enabled     = isTRUE(params$filter_nonspecific),
      name_col    = "pathway",
      size_col    = total_col
    )

    openxlsx::write.xlsx(msea_filt$all,
                         file.path(output_dir, paste0("msea_", prefix, ".xlsx")))
    if (nrow(msea_filt$filtered) < nrow(msea_filt$all)) {
      openxlsx::write.xlsx(msea_filt$filtered,
                           file.path(output_dir, paste0("msea_", prefix, "_filtered.xlsx")))
    }

    msea_sig <- msea_filt$filtered[msea_filt$filtered[, "Raw p"] < 0.05, ]
    if (nrow(msea_sig) > 0) {
      msea_sig$neg_log_p <- -log10(msea_sig[, "Raw p"])
      pw_plot <- .prep_pathway_plot_internal(msea_sig, params$top_n_pathways)

      hits_col     <- if ("hits"     %in% colnames(pw_plot)) "hits"     else "Hits"
      expected_col <- if ("expected" %in% colnames(pw_plot)) "expected" else "Expected"

      p_wf2 <- .make_dot_plot(
        plot_data        = pw_plot,
        x_col            = hits_col,
        y_col            = "pathway",
        size_col         = "neg_log_p",
        color_col        = expected_col,
        title            = "MSEA Enrichment (WF2-ORA)",
        x_label          = "Hits",
        subfig_mode      = params$subfig_mode,
        pathway_gradient = params$pathway_gradient
      )
      save_nature_plot(p_wf2,
                       file.path(output_dir, paste0("msea_", prefix)),
                       width  = params$pathway_fig_w,
                       height = params$pathway_fig_h)
    }

    cat(" 完成/done (", nrow(msea_filt$all), "全部/all,",
        nrow(msea_filt$filtered), "过滤后/filtered)\n")
    invisible(msea_filt)
  }, error = function(e) {
    cat(" 失败/failed:", conditionMessage(e), "\n")
    invisible(NULL)
  })
}


## ========================= WF3: KEGG ORA (KEGGREST + Fisher) =========================

## WF3 KEGG通路富集分析（KEGGREST API + 超几何检验）
## WF3 KEGG pathway enrichment via KEGGREST API + hypergeometric test (Fisher ORA)
##
## @param kegg_ids   KEGG化合物ID向量（如 C00031）/ KEGG compound ID vector
## @param prefix     输出文件前缀 / output file prefix
## @param output_dir 输出目录 / output directory
## @param params     参数列表（另含 $organism KEGG物种代码，如 "dre"）/ parameter list
run_wf3_kegg <- function(kegg_ids, prefix, output_dir, params) {
  cat("  WF3: KEGG Pathway...")

  if (!requireNamespace("KEGGREST", quietly = TRUE)) {
    cat(" 跳过/skipped (KEGGREST未安装/not installed)\n")
    return(invisible(NULL))
  }
  if (length(kegg_ids) < 3) {
    cat(" 跳过/skipped (KEGG IDs不足3个/fewer than 3)\n")
    return(invisible(NULL))
  }

  tryCatch({
    old_timeout <- getOption("timeout")
    options(timeout = 120)
    on.exit(options(timeout = old_timeout), add = TRUE)

    ## 获取物种所有通路 / Retrieve all pathways for the organism
    organism      <- params$organism
    org_pathways  <- KEGGREST::keggList("pathway", organism)
    pw_nums       <- sub(paste0("^", organism), "", names(org_pathways))
    pw_names      <- sub(" - .*$", "", as.character(org_pathways))

    ## 获取化合物-通路映射 / Retrieve compound-to-pathway mapping
    cpd_pw_link   <- KEGGREST::keggLink("pathway", "compound")
    cpd_link_ids  <- sub("cpd:", "", names(cpd_pw_link))
    map_link_ids  <- sub("path:map", "", as.character(cpd_pw_link))

    ## 构建通路-化合物集合 / Build pathway → compound sets
    pw_cpd_sets    <- list()
    all_kegg_cpds  <- character()
    for (i in seq_along(pw_nums)) {
      matched_cpds <- cpd_link_ids[map_link_ids == pw_nums[i]]
      if (length(matched_cpds) >= 2) {
        pw_cpd_sets[[pw_names[i]]] <- matched_cpds
        all_kegg_cpds <- union(all_kegg_cpds, matched_cpds)
      }
    }

    ## 超几何检验 / Hypergeometric test
    N <- length(all_kegg_cpds)
    n <- length(intersect(kegg_ids, all_kegg_cpds))

    kegg_results <- data.frame(
      pathway = character(), Total = integer(), Expected = numeric(),
      Hits = integer(), Raw_p = numeric(), stringsAsFactors = FALSE
    )

    for (pw_name in names(pw_cpd_sets)) {
      pw_cpds  <- pw_cpd_sets[[pw_name]]
      K        <- length(pw_cpds)
      hits     <- intersect(kegg_ids, pw_cpds)
      k        <- length(hits)
      if (k >= 1) {
        expected <- K * n / N
        p_val    <- phyper(k - 1, K, N - K, n, lower.tail = FALSE)
        kegg_results <- rbind(kegg_results, data.frame(
          pathway  = pw_name,
          Total    = K,
          Expected = round(expected, 2),
          Hits     = k,
          Raw_p    = p_val,
          stringsAsFactors = FALSE
        ))
      }
    }

    kegg_results      <- kegg_results[order(kegg_results$Raw_p), ]
    kegg_results$FDR  <- p.adjust(kegg_results$Raw_p, method = "BH")

    ## 过滤 + 写出 / Filter + write
    kegg_filt <- filter_nonspecific(
      kegg_results,
      keywords    = params$nonspecific_keywords,
      size_cutoff = params$nonspecific_size_cutoff,
      enabled     = isTRUE(params$filter_nonspecific),
      name_col    = "pathway",
      size_col    = "Total"
    )
    openxlsx::write.xlsx(kegg_filt$all,
                         file.path(output_dir, paste0("kegg_", prefix, ".xlsx")))
    if (nrow(kegg_filt$filtered) < nrow(kegg_filt$all)) {
      openxlsx::write.xlsx(kegg_filt$filtered,
                           file.path(output_dir, paste0("kegg_", prefix, "_filtered.xlsx")))
    }

    ## 绘图 / Plot
    kegg_plot_data              <- kegg_filt$filtered
    kegg_plot_data$neg_log_p    <- -log10(kegg_plot_data$Raw_p)
    kegg_plot                   <- .prep_pathway_plot_internal(kegg_plot_data, params$top_n_pathways)
    label_size                  <- if (isTRUE(params$subfig_mode)) 3.2 else 2.5

    if (nrow(kegg_plot) > 0) {
      p_mv <- ggplot2::ggplot(kegg_plot, ggplot2::aes(x = Hits, y = neg_log_p)) +
        ggplot2::geom_point(ggplot2::aes(size = Total, fill = neg_log_p),
                            shape = 21, color = "black", stroke = 0.3, alpha = 0.85) +
        ggplot2::scale_fill_gradientn(colours = params$pathway_gradient) +
        ggplot2::scale_size(range = c(2, 10)) +
        ggplot2::geom_hline(yintercept = -log10(0.05), lty = 2,
                            color = "grey50", linewidth = 0.3) +
        ggrepel::geom_text_repel(
          data         = kegg_plot[kegg_plot$Raw_p < 0.1 | kegg_plot$Hits >= 3, ],
          ggplot2::aes(label = pathway),
          size         = label_size,
          max.overlaps = 15,
          segment.color = "grey60",
          segment.size  = 0.3
        ) +
        ggplot2::labs(
          x     = "Hits",
          y     = expression("-log"[10]*"(p-value)"),
          title = paste0("KEGG Pathway Enrichment (", organism, ")"),
          size  = "Pathway Size",
          fill  = expression("-log"[10]*"(p)")
        ) +
        theme_nature(base_size = 8, subfig_mode = params$subfig_mode)

      save_nature_plot(p_mv,
                       file.path(output_dir, paste0("kegg_metabolome_view_", prefix)),
                       width  = params$pathway_fig_w,
                       height = params$pathway_fig_h + 0.5)
    }

    cat(" 完成/done (", nrow(kegg_filt$all), "全部/all,",
        nrow(kegg_filt$filtered), "过滤后/filtered)\n")
    invisible(kegg_filt)
  }, error = function(e) {
    cat(" 失败/failed:", conditionMessage(e), "\n")
    invisible(NULL)
  })
}


## ========================= WF4: QEA (globaltest) =========================

## WF4 定量富集分析（globaltest直接QEA）
## WF4 Quantitative Enrichment Analysis via globaltest (direct QEA)
##
## @param expr_matrix  表达矩阵（features × samples，含Compound.name行名，以及HMDB.ID列）
##                     expression matrix (features × samples; rownames = Compound.name; must have HMDB.ID column)
## @param group_labels 样本分组因子向量（长度=ncol(expr_matrix)）/ sample group factor vector
## @param hmdb_ids     标准化后的HMDB ID向量 / normalized HMDB ID vector
## @param prefix       输出文件前缀 / output file prefix
## @param output_dir   输出目录 / output directory
## @param params       参数列表（同WF1，另含 $hmdb_to_name 映射）/ parameter list
run_wf4_qea <- function(expr_matrix, group_labels, hmdb_ids,
                         prefix, output_dir, params) {
  cat("  WF4: QEA...")

  if (!requireNamespace("globaltest", quietly = TRUE)) {
    cat(" 跳过/skipped (globaltest未安装/not installed)\n")
    return(invisible(NULL))
  }
  if (nrow(expr_matrix) < 5) {
    cat(" 跳过/skipped (代谢物不足5个/fewer than 5 metabolites)\n")
    return(invisible(NULL))
  }

  tryCatch({
    ## 构建samples × metabolites表达矩阵（log2）/ Build samples × metabolites matrix (log2)
    qea_expr <- t(log2(expr_matrix + 1))
    grp      <- factor(group_labels)

    ## 尝试从MetaboAnalystR获取SMPDB通路库 / Try to get SMPDB library from MetaboAnalystR
    pw_lib <- NULL
    if (requireNamespace("MetaboAnalystR", quietly = TRUE)) {
      tryCatch({
        mSet_tmp <- MetaboAnalystR::InitDataObjects("conc", "msetora", FALSE, default.dpi = 72)
        mSet_tmp <- MetaboAnalystR::Setup.MapData(mSet_tmp, hmdb_ids)
        mSet_tmp <- MetaboAnalystR::CrossReferencing(mSet_tmp, "hmdb")
        mSet_tmp <- MetaboAnalystR::CreateMappingResultTable(mSet_tmp)
        mSet_tmp <- MetaboAnalystR::SetMetabolomeFilter(mSet_tmp, FALSE)
        mSet_tmp <- MetaboAnalystR::SetCurrentMsetLib(mSet_tmp, "smpdb_pathway", 0)
        if (file.exists("current.msetlib.qs")) pw_lib <- qs::qread("current.msetlib.qs")
      }, error = function(e) NULL)
    }

    ## 构建通路-代谢物映射 / Build pathway → metabolite mappings
    ## hmdb_to_name: HMDB ID → Compound.name（由调用方在params中提供）
    hmdb_to_name <- params$hmdb_to_name  # named character: names=HMDB IDs, values=compound names

    pw_sets <- list()
    if (!is.null(pw_lib)) {
      for (i in seq_len(nrow(pw_lib))) {
        pw_name    <- pw_lib$name[i]
        pw_members <- if (is.list(pw_lib$member)) {
          pw_lib$member[[i]]
        } else {
          unlist(strsplit(as.character(pw_lib$member[i]), "; "))
        }
        ## 直接名称匹配 / Direct name match
        mapped      <- intersect(pw_members, colnames(qea_expr))
        ## HMDB → 化合物名匹配 / HMDB → compound name match
        hmdb_mapped <- hmdb_to_name[pw_members[pw_members %in% names(hmdb_to_name)]]
        all_mapped  <- unique(c(mapped, hmdb_mapped[hmdb_mapped %in% colnames(qea_expr)]))
        if (length(all_mapped) >= 2) pw_sets[[pw_name]] <- all_mapped
      }

      ## Fallback：仅直接名称匹配 / Fallback: direct name matching only
      if (length(pw_sets) == 0) {
        for (i in seq_len(nrow(pw_lib))) {
          pw_name    <- pw_lib$name[i]
          pw_members <- if (is.list(pw_lib$member)) {
            pw_lib$member[[i]]
          } else {
            unlist(strsplit(as.character(pw_lib$member[i]), "; "))
          }
          mapped <- intersect(pw_members, colnames(qea_expr))
          if (length(mapped) >= 2) pw_sets[[pw_name]] <- mapped
        }
      }
    }

    if (length(pw_sets) < 1) {
      cat(" 无足够通路映射/not enough pathway mappings\n")
      return(invisible(NULL))
    }

    ## 对每个通路运行globaltest / Run globaltest per pathway
    qea_results <- data.frame(
      pathway   = character(),
      p_value   = numeric(),
      statistic = numeric(),
      hits      = integer(),
      stringsAsFactors = FALSE
    )
    for (pw_name in names(pw_sets)) {
      pw_cols  <- pw_sets[[pw_name]]
      pw_idx   <- which(colnames(qea_expr) %in% pw_cols)
      gt_res   <- globaltest::gt(grp, qea_expr[, pw_idx, drop = FALSE])
      qea_results <- rbind(qea_results, data.frame(
        pathway   = pw_name,
        p_value   = globaltest::p.value(gt_res),
        statistic = gt_res@result[1, "Statistic"],
        hits      = length(pw_idx)
      ))
    }
    qea_results      <- qea_results[order(qea_results$p_value), ]
    qea_results$FDR  <- p.adjust(qea_results$p_value, method = "BH")

    ## 过滤 + 写出 / Filter + write
    qea_filt <- filter_nonspecific(
      qea_results,
      keywords    = params$nonspecific_keywords,
      size_cutoff = params$nonspecific_size_cutoff,
      enabled     = isTRUE(params$filter_nonspecific),
      name_col    = "pathway"
    )
    openxlsx::write.xlsx(qea_filt$all,
                         file.path(output_dir, paste0("qea_", prefix, ".xlsx")))
    if (nrow(qea_filt$filtered) < nrow(qea_filt$all)) {
      openxlsx::write.xlsx(qea_filt$filtered,
                           file.path(output_dir, paste0("qea_", prefix, "_filtered.xlsx")))
    }

    qea_sig <- qea_filt$filtered[qea_filt$filtered$p_value < 0.05, ]
    if (nrow(qea_sig) > 0) {
      qea_sig$neg_log_p <- -log10(qea_sig$p_value)
      pw_plot <- .prep_pathway_plot_internal(qea_sig, params$top_n_pathways)

      p_wf4 <- .make_dot_plot(
        plot_data        = pw_plot,
        x_col            = "hits",
        y_col            = "pathway",
        size_col         = "neg_log_p",
        color_col        = "statistic",
        title            = "QEA Enrichment (WF4-GlobalTest)",
        x_label          = "Hits",
        subfig_mode      = params$subfig_mode,
        pathway_gradient = params$pathway_gradient
      )
      save_nature_plot(p_wf4,
                       file.path(output_dir, paste0("qea_", prefix)),
                       width  = params$pathway_fig_w,
                       height = params$pathway_fig_h)
    }

    cat(" 完成/done (", nrow(qea_filt$all), "全部/all,",
        nrow(qea_filt$filtered), "过滤后/filtered)\n")
    invisible(qea_filt)
  }, error = function(e) {
    cat(" 失败/failed:", conditionMessage(e), "\n")
    invisible(NULL)
  })
}


## ========================= 编排器 / Orchestrator =========================

## 四工作流总编排：对单个差异代谢物集运行WF1-4
## Orchestrator: runs WF1-4 for a single differential metabolite set
##
## @param merged_data  合并了注释+差异+表达的data.frame
##                     data.frame merging annotation + differential + expression columns
##   必须含 / must contain: variable_id, Compound.name, HMDB.ID, KEGG.ID, logFC, adj.P.Val/P.Value
##   表达列：sample_cols参数指定的列 / expression columns: specified by sample_cols param
## @param prefix       输出文件前缀（不含目录）/ output file prefix (no directory)
## @param output_dir   输出目录路径 / output directory path
## @param params       参数列表 / parameter list containing:
##   $alpha, $fc_cut, $organism, $top_n_pathways, $filter_nonspecific,
##   $pathway_fig_w, $pathway_fig_h, $subfig_mode,
##   $nonspecific_keywords, $nonspecific_size_cutoff, $pathway_gradient,
##   $sample_cols  — 表达列名向量 / expression column names in merged_data
##   $control_group, $model_group — 分组名称（用于热图注释）
##   $nature_colors — 热图注释色 / color for heatmap annotation
##   $heatmap_colors — 热图色带 / heatmap color ramp
run_quad_workflow <- function(merged_data, prefix, output_dir, params) {
  cat("\n------ 处理/Processing:", prefix, "------\n")

  ## 提取 ID / Extract IDs
  HMDB_ids  <- normalize_hmdb(merged_data$HMDB.ID)
  KEGG_ids  <- unique(merged_data$KEGG.ID[!is.na(merged_data$KEGG.ID) &
                                           merged_data$KEGG.ID != ""])
  sample_cols <- params$sample_cols

  cat("  差异代谢物/Diff metabolites:", nrow(merged_data),
      "| HMDB:", length(HMDB_ids), "| KEGG:", length(KEGG_ids), "\n")

  ## WF1 —————————————————————————————————————————
  run_wf1_smpdb(HMDB_ids, prefix, output_dir, params)

  ## WF2 —————————————————————————————————————————
  run_wf2_msea(HMDB_ids, prefix, output_dir, params)

  ## WF3 —————————————————————————————————————————
  run_wf3_kegg(KEGG_ids, prefix, output_dir, params)

  ## WF4 —————————————————————————————————————————
  ## 准备QEA输入矩阵 / Prepare QEA input matrix
  qea_sub <- merged_data[!is.na(merged_data$Compound.name) &
                          merged_data$Compound.name != "", ]
  qea_sub <- dplyr::distinct(qea_sub, Compound.name, .keep_all = TRUE)

  if (nrow(qea_sub) >= 5) {
    qea_mat              <- as.matrix(qea_sub[, sample_cols])
    rownames(qea_mat)    <- qea_sub$Compound.name
    group_labels         <- factor(gsub("[0-9]", "", colnames(qea_mat)))
    hmdb_to_name         <- stats::setNames(qea_sub$Compound.name,
                                            normalize_hmdb(qea_sub$HMDB.ID))
    params$hmdb_to_name  <- hmdb_to_name

    run_wf4_qea(qea_mat, group_labels, HMDB_ids, prefix, output_dir, params)
  } else {
    cat("  WF4: 跳过/skipped (代谢物不足5个)\n")
  }

  ## 热图 / Heatmap —————————————————————————————
  cat("  Heatmap...")
  tryCatch({
    heat_data          <- merged_data[, c("Compound.name", sample_cols)]
    heat_data          <- dplyr::distinct(heat_data, Compound.name, .keep_all = TRUE)
    rownames(heat_data) <- heat_data$Compound.name
    heat_data          <- heat_data[, -1, drop = FALSE]
    heat_data          <- as.data.frame(lapply(heat_data, as.numeric))
    rownames(heat_data) <- merged_data %>%
      dplyr::distinct(Compound.name, .keep_all = TRUE) %>%
      dplyr::pull(Compound.name)

    group_vec <- gsub("[0-9]", "", colnames(heat_data))
    col_anno  <- data.frame(Group = group_vec, row.names = colnames(heat_data))
    anno_colors <- list(
      Group = stats::setNames(
        params$nature_colors[c(4, 1)],
        c(params$control_group, params$model_group)
      )
    )

    if (nrow(heat_data) > 1 && ncol(heat_data) > 1) {
      fig_height <- max(9, nrow(heat_data) * 0.15 + 2)

      p_heat <- pheatmap::pheatmap(
        heat_data, cluster_cols = TRUE, cluster_rows = TRUE,
        scale = "row", show_colnames = TRUE,
        fontsize = 7, fontsize_row = 6, fontsize_col = 7,
        color = params$heatmap_colors, border_color = NA,
        annotation_col = col_anno, annotation_colors = anno_colors,
        cellwidth = 16, cellheight = 10, silent = TRUE
      )

      pdf(file.path(output_dir, paste0("heatmap_", prefix, ".pdf")),
          width = 7, height = fig_height)
      print(p_heat)
      grDevices::dev.off()

      grDevices::tiff(file.path(output_dir, paste0("heatmap_", prefix, ".tiff")),
                      width = 7, height = fig_height, units = "in",
                      res = 300, compression = "lzw")
      print(p_heat)
      grDevices::dev.off()

      cat(" 完成/done\n")
    } else {
      cat(" 跳过(数据不足)/skipped\n")
    }
  }, error = function(e) cat(" 失败/failed:", conditionMessage(e), "\n"))

  ## 汇总 / Summary —————————————————————————————
  summary_df <- data.frame(
    Parameter = c("Diff_metabolites", "HMDB_IDs", "KEGG_IDs",
                  "logFC_base", "logFC_cutoff", "Significance",
                  "Organism", "Polarity"),
    Value     = c(nrow(merged_data), length(HMDB_ids), length(KEGG_ids),
                  "log10", params$fc_cut, paste0("adj.P.Val < ", params$alpha),
                  params$organism, params$polarity)
  )
  openxlsx::write.xlsx(summary_df,
                       file.path(output_dir, paste0("summary_", prefix, ".xlsx")))

  invisible(NULL)
}


## ========================= 内部工具 / Internal Helpers =========================

## 通路图数据准备（内部版，接受top_n参数）
## Prepare pathway plot data (internal version, accepts top_n as parameter)
.prep_pathway_plot_internal <- function(df, top_n = 0) {
  if (nrow(df) == 0) return(df)
  n <- if (!is.null(top_n) && top_n > 0) top_n else nrow(df)
  n <- min(n, nrow(df))
  df[seq_len(n), ]
}


## ========================= 导出工具函数 / Exported Utility Functions =========================

## HMDB ID标准化（7位→11位，去重，去NA）
## Normalize HMDB IDs from 7-digit to 11-digit format, deduplicate, remove NAs
## @param ids HMDB ID字符向量 / character vector of HMDB IDs
## @return 标准化后的唯一HMDB ID向量 / unique normalized HMDB ID vector
normalize_hmdb <- function(ids) {
  ids <- ids[!is.na(ids) & ids != ""]
  ids <- ifelse(
    nchar(ids) == 11 & grepl("^HMDB\\d{5}$", ids),
    paste0("HMDB00", substring(ids, 5)),
    ids
  )
  unique(ids)
}


## 非特异性通路过滤
## Filter non-specific pathways using keyword blacklist and size cutoff
## @param df          通路结果data.frame / pathway result data.frame
## @param keywords    关键词黑名单向量 / blacklist keyword vector
## @param size_cutoff 通路大小上限 / pathway size ceiling
## @param enabled     是否启用过滤（FALSE时原样返回）/ whether filtering is active
## @param name_col    通路名列名 / column name for pathway names
## @param size_col    通路大小列名（NULL=跳过大小过滤）/ column for pathway size (NULL = skip)
## @return list(all = 原始, filtered = 过滤后) / list(all = original, filtered = filtered)
filter_nonspecific <- function(df,
                                keywords     = NONSPECIFIC_KEYWORDS,
                                size_cutoff  = NONSPECIFIC_SIZE_CUTOFF,
                                enabled      = TRUE,
                                name_col     = "pathway_name",
                                size_col     = NULL) {
  if (nrow(df) == 0) return(list(all = df, filtered = df))

  if (!isTRUE(enabled)) return(list(all = df, filtered = df))

  ## 关键词匹配过滤 / Keyword match filter
  blacklist_hit <- sapply(df[[name_col]], function(pw) {
    any(sapply(keywords, function(kw) grepl(kw, pw, ignore.case = TRUE)))
  })

  ## 大小过滤 / Size filter
  size_hit <- rep(FALSE, nrow(df))
  if (!is.null(size_col) && size_col %in% colnames(df)) {
    size_hit <- df[[size_col]] > size_cutoff
  }

  keep <- !(blacklist_hit | size_hit)
  list(all = df, filtered = df[keep, , drop = FALSE])
}

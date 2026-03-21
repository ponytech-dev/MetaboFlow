# 报告导出系统设计

> 确认日期：2026-03-21
> 状态：已确认

## 概述

PDF + Word 双格式报告导出，含自动生成的可发表 Methods 段落。

## 双格式输出

| 格式 | 渲染引擎 | 用途 |
|------|---------|------|
| PDF | Quarto（R Markdown 继任） | 正式报告，排版精确，发给导师/审稿人 |
| Word | officer R 包 | 可编辑，用户直接复制 Methods 段落到论文 |

## 报告结构

```
1. Analysis Summary（样本信息、引擎版本、参数快照）
2. Quality Control（TIC overlay、CV 分布、PCA QC 概览）
3. Feature Detection（feature 数、去冗余后 compound 数）
4. Statistical Analysis（差异代谢物数、火山图、热图）
5. Annotation（注释命中率、MSI level 分布、top hits 表）
6. Pathway Enrichment（显著通路列表、气泡图）
7. Methods（自动生成的可发表 Methods 段落）
8. Appendix（完整参数表、软件版本表）
```

## 自动 Methods 段落

根据用户选择的引擎和参数，自动拼装 Methods 文本。每个引擎/参数对应一段模板文本，运行时参数值填入占位符。

示例输出：

> *Untargeted metabolomics data were processed using MetaboFlow (v1.0). Peak detection was performed with XCMS (v4.4.0, centWave method, ppm = 15, snthresh = 10). Feature grouping and retention time correction were applied using the obiwarp method. Redundant features were removed using CAMERA (v1.56.0). Statistical analysis was performed using limma (v3.60.0) with Benjamini-Hochberg FDR correction (adjusted p < 0.05, |log2FC| > 1). Metabolite annotation was performed against the MetaboFlow Spectral Library (MFSL v2.2, 960,000 compounds) using matchms (v0.24) with cosine similarity ≥ 0.7.*

## 报告中的图表

- 复用图表模板系统生成的 PNG（300 dpi），不重新渲染
- 用户可在结果页选择哪些图表放入报告

## 图表选择

- 图表选择 UI 在 `/projects/:id/report` 页面（不在 Results 页）
- 用户勾选要放入报告的图表 → 选择状态存入 DB（analysis 关联）→ 刷新后保留
- 报告生成为异步操作，SSE 推送渲染进度

## 技术实现

- PDF：Quarto `.qmd` 模板 + R 渲染
- Word：officer R 包，预设 Word 模板（含 MetaboFlow 页眉页脚）
- Methods 模板：YAML 配置文件，每个引擎一段模板文本 + 参数占位符
- Quarto 运行在 stats-worker 容器（已有 R + 依赖），版本锁定在 Dockerfile 中
- 渲染时通过共享 `/data` volume 访问 PNG 文件
